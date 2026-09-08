//! The FFI surface.
//!
//! Every call is either instant or spawned, so none blocks a Dart isolate: a
//! transfer is started by handle and reported on the event stream.

use std::collections::HashMap;
use std::path::PathBuf;
#[cfg(unix)]
use std::os::fd::FromRawFd;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Mutex, OnceLock};

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::UnboundedReceiver;
use tokio_util::sync::CancellationToken;

use crate::client::{send_files, FileSource, OutgoingFile};
use crate::events::{Direction, EventSink, TransferEvent};
use crate::server::{DataServer, IncomingFile};

// ---------------------------------------------------------------------------
// Types crossing the boundary
// ---------------------------------------------------------------------------

/// A file this device is about to receive.
///
/// `destination` is an absolute path chosen by Dart. The sender's filename
/// never reaches Rust; `lib/utils/save_path.dart` sanitises it and resolves
/// collisions.
pub struct IncomingFileSpec {
    pub destination: String,
    /// Signed because flutter_rust_bridge maps `u64` to Dart's `BigInt` and
    /// `i64` to its plain `int`. Negative is refused.
    pub size: i64,
}

/// A file this device is about to send.
pub struct OutgoingFileSpec {
    /// Absolute path to the file, or empty when [`fd`](Self::fd) carries it.
    pub source: String,

    /// A descriptor the platform layer already opened, when the file has no
    /// path this process could use — on Android, a `content://` URI.
    ///
    /// **Ownership passes with it.** Nothing on the Dart or Kotlin side closes
    /// it; adopting it into an `OwnedFd` below closes it exactly once.
    pub fd: Option<i32>,

    /// See [`IncomingFileSpec::size`].
    pub size: i64,
}

/// What happened, for both directions.
///
/// Flat rather than variant-carrying: that shape would make
/// flutter_rust_bridge generate a freezed union, and a second build_runner
/// pass. `lib/transfer/data_plane.dart` turns it into a sealed class on
/// arrival.
pub enum DataPlaneEventKind {
    Progress,
    FileFinished,
    Failed,
    Cancelled,
}

/// `sending` says which half of a transfer this came from: true for a send
/// this device started, false for a file arriving. Both halves share the
/// stream.
///
/// `session` is the token the control channel issued. `transferred` carries
/// the byte count in every case, including the partial length after a failure
/// or cancellation. `message` is empty except on
/// [`DataPlaneEventKind::Failed`].
pub struct DataPlaneEvent {
    pub kind: DataPlaneEventKind,
    pub sending: bool,
    pub session: String,
    pub index: u32,
    pub transferred: i64,
    pub total: i64,
    pub message: String,
}

impl From<(Direction, TransferEvent)> for DataPlaneEvent {
    fn from((direction, event): (Direction, TransferEvent)) -> Self {
        let sending = direction == Direction::Sending;
        match event {
            TransferEvent::Progress {
                session,
                index,
                transferred,
                total,
            } => Self {
                kind: DataPlaneEventKind::Progress,
                sending,
                session,
                index,
                transferred: transferred as i64,
                total: total as i64,
                message: String::new(),
            },
            TransferEvent::FileFinished { session, index } => Self {
                kind: DataPlaneEventKind::FileFinished,
                sending,
                session,
                index,
                transferred: 0,
                total: 0,
                message: String::new(),
            },
            TransferEvent::Failed {
                session,
                index,
                partial,
                message,
            } => Self {
                kind: DataPlaneEventKind::Failed,
                sending,
                session,
                index,
                transferred: partial as i64,
                total: 0,
                message,
            },
            TransferEvent::Cancelled {
                session,
                index,
                partial,
            } => Self {
                kind: DataPlaneEventKind::Cancelled,
                sending,
                session,
                index,
                transferred: partial as i64,
                total: 0,
                message: String::new(),
            },
        }
    }
}

// ---------------------------------------------------------------------------
// Process-wide state
// ---------------------------------------------------------------------------

/// One runtime for the life of the process.
///
/// Owned here rather than left to flutter_rust_bridge's executor: axum and
/// reqwest need tokio's io and time drivers, and the server has to outlive the
/// call that started it.
static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static SERVER: Mutex<Option<DataServer>> = Mutex::new(None);
static EVENTS: OnceLock<EventSink> = OnceLock::new();
static PENDING_EVENTS: Mutex<Option<UnboundedReceiver<(Direction, TransferEvent)>>> =
    Mutex::new(None);
static TASKS: OnceLock<Mutex<HashMap<i64, CancellationToken>>> = OnceLock::new();
static NEXT_TASK: AtomicI64 = AtomicI64::new(1);

fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            // Two threads overlap a socket with a disk write, which is all a
            // transfer needs.
            .worker_threads(2)
            .enable_all()
            .thread_name("jett-data")
            .build()
            .expect("could not start the data plane runtime")
    })
}

fn events() -> EventSink {
    EVENTS
        .get_or_init(|| {
            let (sender, receiver) = tokio::sync::mpsc::unbounded_channel();
            *PENDING_EVENTS.lock().unwrap() = Some(receiver);
            // Receiving by default; the sending half asks for its own stamp.
            EventSink::new(sender, Direction::Receiving)
        })
        .clone()
}

fn tasks() -> &'static Mutex<HashMap<i64, CancellationToken>> {
    TASKS.get_or_init(Default::default)
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Prepares the runtime. Safe to call more than once.
///
/// Called from `main()` so the first transfer does not pay for thread creation.
#[frb(sync)]
pub fn init_data_plane() {
    let _ = runtime();
    let _ = events();
}

/// The single event stream, consumed once at startup.
///
/// Progress is throttled here to roughly ten events per second per active file.
pub fn data_plane_events(sink: StreamSink<DataPlaneEvent>) {
    let receiver = PENDING_EVENTS.lock().unwrap().take();
    let Some(mut receiver) = receiver else {
        // Already consumed; dropping the sink closes the duplicate stream
        // rather than competing with the live one.
        return;
    };

    runtime().spawn(async move {
        while let Some(event) = receiver.recv().await {
            if sink.add(event.into()).is_err() {
                break;
            }
        }
    });
}

// ---------------------------------------------------------------------------
// Receiving
// ---------------------------------------------------------------------------

/// Starts the data-plane listener and returns the port it bound.
///
/// Pass 0 to let the OS choose, then advertise the returned port over the
/// existing presence broadcast.
pub fn start_server(
    certificate_pem: String,
    private_key_pem: String,
    port: u16,
) -> Result<u16, String> {
    let sink = events().for_direction(Direction::Receiving);
    runtime().block_on(async move {
        let server = DataServer::start(&certificate_pem, &private_key_pem, port, sink)
            .await
            .map_err(|e| e.to_string())?;
        let bound = server.port();
        *SERVER.lock().unwrap() = Some(server);
        Ok(bound)
    })
}

/// Authorises a session, after the control channel has verified the peer and
/// the user has accepted the files.
///
/// Until this is called, a `PUT` carrying the token is answered with 404.
pub fn open_session(token: String, files: Vec<IncomingFileSpec>) -> Result<(), String> {
    let files = files
        .into_iter()
        .map(|file| {
            if file.size < 0 {
                return Err(format!("{} was offered a negative size", file.destination));
            }
            Ok(IncomingFile {
                destination: PathBuf::from(file.destination),
                size: file.size as u64,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;

    with_server(|server| {
        runtime().block_on(server.open_session(token, files));
        Ok(())
    })
}

/// Retires a session token so it cannot be replayed once the exchange is over.
pub fn close_session(token: String) -> Result<(), String> {
    with_server(|server| {
        runtime().block_on(server.close_session(&token));
        Ok(())
    })
}

/// Stops listening, letting in-flight writes finish first so a partial file
/// keeps an accurate length for resume.
pub fn stop_server(grace_millis: u32) -> Result<(), String> {
    let server = SERVER.lock().unwrap().take();
    if let Some(server) = server {
        runtime().block_on(server.shutdown(std::time::Duration::from_millis(grace_millis as u64)));
    }
    Ok(())
}

fn with_server<T>(f: impl FnOnce(&DataServer) -> Result<T, String>) -> Result<T, String> {
    let guard = SERVER.lock().unwrap();
    let server = guard.as_ref().ok_or("data plane server is not running")?;
    f(server)
}

// ---------------------------------------------------------------------------
// Sending
// ---------------------------------------------------------------------------

/// Begins a send and returns immediately with a handle for [`cancel_send`].
///
/// Outcomes arrive on the event stream; the handle keeps the call off the
/// isolate for the whole transfer.
#[frb(sync)]
pub fn start_send(
    base_url: String,
    token: String,
    peer_fingerprint: String,
    files: Vec<OutgoingFileSpec>,
) -> i64 {
    let task_id = NEXT_TASK.fetch_add(1, Ordering::Relaxed);
    let cancel = CancellationToken::new();
    tasks().lock().unwrap().insert(task_id, cancel.clone());

    // Adopted before anything can fail, so every descriptor has an owner that
    // closes it even if a later file errors.
    let files: Vec<OutgoingFile> = files
        .into_iter()
        .map(|file| OutgoingFile {
            source: match file.fd {
                #[cfg(unix)]
                Some(fd) => {
                    // SAFETY: the platform layer detached this descriptor to hand
                    // it over (see `openFileDescriptor` in `pigeons/input.dart`),
                    // so nothing else owns or will close it.
                    FileSource::Descriptor(unsafe {
                        std::os::fd::OwnedFd::from_raw_fd(fd)
                    })
                }
                // No descriptor to adopt off Unix; the path is the only source.
                _ => FileSource::Path(PathBuf::from(file.source)),
            },
            size: file.size.max(0) as u64,
        })
        .collect();
    let sink = events().for_direction(Direction::Sending);

    runtime().spawn(async move {
        // `send_files` already reports failures as events.
        let _ = send_files(
            &base_url,
            &token,
            &peer_fingerprint,
            files,
            sink,
            cancel,
        )
        .await;
        tasks().lock().unwrap().remove(&task_id);
    });

    task_id
}

/// Closes a descriptor that was opened for a send which then did not happen.
///
/// [`start_send`] adopts every descriptor it is given, so this covers only the
/// send that never starts, which Dart cannot close itself.
///
/// Closing a descriptor that was never open, or one already closed, is ignored.
#[frb(sync)]
pub fn close_descriptor(fd: i32) {
    #[cfg(unix)]
    {
        if fd < 0 {
            return;
        }
        // SAFETY: the caller owns this descriptor and is giving it up, the same
        // transfer `start_send` relies on. The `OwnedFd` closes it once.
        drop(unsafe { std::os::fd::OwnedFd::from_raw_fd(fd) });
    }
    #[cfg(not(unix))]
    {
        let _ = fd;
    }
}

/// Stops a send. The peer keeps what it already wrote, so a later attempt
/// resumes from there rather than starting over.
#[frb(sync)]
pub fn cancel_send(task_id: i64) {
    if let Some(cancel) = tasks().lock().unwrap().remove(&task_id) {
        cancel.cancel();
    }
}

/// The fingerprint of a certificate, so Rust's reading of a peer can be
/// compared against Dart's in a test.
#[frb(sync)]
pub fn fingerprint_of_certificate(certificate_der: Vec<u8>) -> Result<String, String> {
    crate::fingerprint::fingerprint_of_der(&certificate_der).map_err(|e| e.to_string())
}
