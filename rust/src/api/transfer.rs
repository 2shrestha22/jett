//! The FFI surface.
//!
//! Ten functions and two types. Everything is either instant or spawned, so no
//! call from Dart ever blocks an isolate: a transfer is started by handle and
//! reported on the event stream.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;
use tokio::runtime::Runtime;
use tokio::sync::mpsc::UnboundedReceiver;
use tokio_util::sync::CancellationToken;

use crate::client::{send_files, OutgoingFile};
use crate::events::{EventSink, TransferEvent};
use crate::server::{DataServer, IncomingFile};

// ---------------------------------------------------------------------------
// Types crossing the boundary
// ---------------------------------------------------------------------------

/// A file this device is about to receive.
///
/// `destination` is an absolute path chosen by Dart. The sender's filename
/// never reaches Rust: `lib/utils/save_path.dart` already sanitises it and
/// resolves collisions, and re-deciding that here would be a second chance to
/// get path traversal wrong.
pub struct IncomingFileSpec {
    pub destination: String,
    pub size: u64,
}

/// A file this device is about to send.
pub struct OutgoingFileSpec {
    pub source: String,
    pub size: u64,
}

/// What happened, for both directions.
///
/// Flat rather than a variant-carrying enum on purpose: that shape would make
/// flutter_rust_bridge generate a freezed union, which means adding `freezed`
/// and a second build_runner pass to an app that already runs one for
/// dart_mappable. The boundary type stays dumb and `lib/transfer/data_plane.dart`
/// turns it into a real sealed class on arrival — Dart 3 needs no codegen for
/// that.
pub enum DataPlaneEventKind {
    Progress,
    FileFinished,
    Failed,
    Cancelled,
}

/// `session` is the token the control channel issued, so Dart can attribute an
/// event without keeping its own map of task ids.
///
/// `transferred` carries the byte count in every case, including the partial
/// length after a failure or a cancellation — which is exactly where a resume
/// would pick up. `message` is empty except on [`DataPlaneEventKind::Failed`].
pub struct DataPlaneEvent {
    pub kind: DataPlaneEventKind,
    pub session: String,
    pub index: u32,
    pub transferred: u64,
    pub total: u64,
    pub message: String,
}

impl From<TransferEvent> for DataPlaneEvent {
    fn from(event: TransferEvent) -> Self {
        match event {
            TransferEvent::Progress {
                session,
                index,
                transferred,
                total,
            } => Self {
                kind: DataPlaneEventKind::Progress,
                session,
                index,
                transferred,
                total,
                message: String::new(),
            },
            TransferEvent::FileFinished { session, index } => Self {
                kind: DataPlaneEventKind::FileFinished,
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
                session,
                index,
                transferred: partial,
                total: 0,
                message,
            },
            TransferEvent::Cancelled {
                session,
                index,
                partial,
            } => Self {
                kind: DataPlaneEventKind::Cancelled,
                session,
                index,
                transferred: partial,
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
/// Owned here rather than left to flutter_rust_bridge's executor because axum
/// and reqwest need tokio's io and time drivers specifically, and because a
/// server has to outlive the call that started it.
static RUNTIME: OnceLock<Runtime> = OnceLock::new();
static SERVER: Mutex<Option<DataServer>> = Mutex::new(None);
static EVENTS: OnceLock<EventSink> = OnceLock::new();
static PENDING_EVENTS: Mutex<Option<UnboundedReceiver<TransferEvent>>> = Mutex::new(None);
static TASKS: OnceLock<Mutex<HashMap<u64, CancellationToken>>> = OnceLock::new();
static NEXT_TASK: AtomicU64 = AtomicU64::new(1);

fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            // Two threads is enough to overlap a socket with a disk write,
            // which is all a transfer needs. A thread per core would mostly buy
            // idle stacks on a phone.
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
            EventSink::new(sender)
        })
        .clone()
}

fn tasks() -> &'static Mutex<HashMap<u64, CancellationToken>> {
    TASKS.get_or_init(Default::default)
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

/// Prepares the runtime. Safe to call more than once.
///
/// Called from `main()` before the first frame so that the first transfer does
/// not pay for thread creation.
#[frb(sync)]
pub fn init_data_plane() {
    let _ = runtime();
    let _ = events();
}

/// The single event stream, consumed once at startup.
///
/// Progress is already throttled on the Rust side, so this delivers roughly ten
/// events per second per active file rather than one per chunk.
pub fn data_plane_events(sink: StreamSink<DataPlaneEvent>) {
    let receiver = PENDING_EVENTS.lock().unwrap().take();
    let Some(mut receiver) = receiver else {
        // Already consumed. Dropping the sink closes the duplicate stream
        // rather than silently competing with the live one for events.
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
    let sink = events();
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
/// Until this is called, a `PUT` carrying the token is answered with 404 — the
/// token is a receipt for a decision made elsewhere, not a credential in itself.
pub fn open_session(token: String, files: Vec<IncomingFileSpec>) -> Result<(), String> {
    let files = files
        .into_iter()
        .map(|file| IncomingFile {
            destination: PathBuf::from(file.destination),
            size: file.size,
        })
        .collect();

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

/// Stops listening, letting in-flight writes finish first.
///
/// A hard stop mid-write would leave a partial file with no accurate record of
/// how far it got, which is the one thing resume depends on.
pub fn stop_server(grace_millis: u64) -> Result<(), String> {
    let server = SERVER.lock().unwrap().take();
    if let Some(server) = server {
        runtime().block_on(server.shutdown(std::time::Duration::from_millis(grace_millis)));
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
/// Outcomes arrive on the event stream. Returning a handle rather than a future
/// keeps the call off the isolate for the whole transfer, which for a large file
/// is the difference between a responsive UI and a frozen one.
#[frb(sync)]
pub fn start_send(
    base_url: String,
    token: String,
    peer_fingerprint: String,
    files: Vec<OutgoingFileSpec>,
) -> u64 {
    let task_id = NEXT_TASK.fetch_add(1, Ordering::Relaxed);
    let cancel = CancellationToken::new();
    tasks().lock().unwrap().insert(task_id, cancel.clone());

    let files: Vec<OutgoingFile> = files
        .into_iter()
        .map(|file| OutgoingFile {
            source: PathBuf::from(file.source),
            size: file.size,
        })
        .collect();
    let sink = events();

    runtime().spawn(async move {
        // Failures are already reported as events by `send_files`; the returned
        // error would only be a duplicate with nowhere to go.
        let _ = send_files(
            &base_url,
            &token,
            &peer_fingerprint,
            &files,
            sink,
            cancel,
        )
        .await;
        tasks().lock().unwrap().remove(&task_id);
    });

    task_id
}

/// Stops a send. The peer keeps what it already wrote, so a later attempt
/// resumes from there rather than starting over.
#[frb(sync)]
pub fn cancel_send(task_id: u64) {
    if let Some(cancel) = tasks().lock().unwrap().remove(&task_id) {
        cancel.cancel();
    }
}

/// The fingerprint of a certificate, for the rare case Dart wants Rust's
/// reading of a peer rather than its own. Exposed mainly so the two can be
/// compared in a test on a real device.
#[frb(sync)]
pub fn fingerprint_of_certificate(certificate_der: Vec<u8>) -> Result<String, String> {
    crate::fingerprint::fingerprint_of_der(&certificate_der).map_err(|e| e.to_string())
}
