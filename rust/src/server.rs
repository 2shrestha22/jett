//! The receiving half: an axum server whose request bodies are file contents.
//!
//! A `PUT` here is a seek and a write. Nothing decodes the body or buffers the
//! file in memory. See [`crate::protocol`].

use std::collections::HashMap;
use std::net::{Ipv4Addr, SocketAddr};
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use axum::body::Body;
use axum::extract::{Path, State};
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::put;
use axum::Router;
use futures_util::StreamExt;
use tokio::io::{AsyncSeekExt, AsyncWriteExt, BufWriter};
use tokio::sync::RwLock;

use crate::events::{EventSink, ProgressThrottle, TransferEvent};
use crate::protocol::RECEIVED_HEADER;

/// Writes are coalesced to this size before reaching the filesystem.
///
/// hyper hands over network-sized chunks, and a write syscall per chunk is
/// measurable at gigabit speeds.
const WRITE_BUFFER_BYTES: usize = 1024 * 1024;

/// A file the control channel has already agreed to accept.
#[derive(Debug, Clone)]
pub struct IncomingFile {
    /// Where this file lands, decided entirely by Dart. The sender's filename
    /// never reaches this crate; `lib/utils/save_path.dart` sanitises it and
    /// resolves collisions.
    pub destination: PathBuf,
    pub size: u64,
}

struct Session {
    files: Vec<IncomingFile>,
    received: Vec<AtomicU64>,
}

impl Session {
    fn new(files: Vec<IncomingFile>) -> Self {
        let received = files.iter().map(|_| AtomicU64::new(0)).collect();
        Self { files, received }
    }
}

#[derive(Clone)]
struct ServerState {
    sessions: Arc<RwLock<HashMap<String, Arc<Session>>>>,
    events: EventSink,
}

/// A running data-plane server.
pub struct DataServer {
    handle: axum_server::Handle,
    port: u16,
    sessions: Arc<RwLock<HashMap<String, Arc<Session>>>>,
    /// Kept so [`DataServer::shutdown`] can wait for in-flight writes.
    serving: tokio::task::JoinHandle<()>,
}

impl DataServer {
    /// Binds and starts serving. `port` may be 0 to let the OS choose; the
    /// port actually bound is on [`DataServer::port`].
    pub async fn start(
        certificate_pem: &str,
        private_key_pem: &str,
        port: u16,
        events: EventSink,
    ) -> anyhow::Result<Self> {
        let tls = crate::tls::server_config(certificate_pem, private_key_pem)?;
        let sessions: Arc<RwLock<HashMap<String, Arc<Session>>>> = Default::default();

        let app = Router::new()
            .route(
                "/v2/blob/{token}/{index}",
                put(receive_blob).head(received_so_far),
            )
            .with_state(ServerState {
                sessions: sessions.clone(),
                events,
            });

        let handle = axum_server::Handle::new();
        let config = axum_server::tls_rustls::RustlsConfig::from_config(Arc::new(tls));
        let address = SocketAddr::from((Ipv4Addr::UNSPECIFIED, port));

        let server = axum_server::bind_rustls(address, config)
            .handle(handle.clone())
            .serve(app.into_make_service());

        // Runs until the handle shuts it down. A bind failure surfaces as
        // `listening()` returning None, turned back into an error below.
        let serving = tokio::spawn(async move {
            if let Err(error) = server.await {
                tracing::error!(%error, "data plane server stopped");
            }
        });

        let bound = handle
            .listening()
            .await
            .ok_or_else(|| anyhow::anyhow!("could not bind data plane to port {port}"))?;

        Ok(Self {
            handle,
            port: bound.port(),
            sessions,
            serving,
        })
    }

    pub fn port(&self) -> u16 {
        self.port
    }

    /// Opens a session. Called once the control channel has verified the peer
    /// and the user has accepted the files.
    pub async fn open_session(&self, token: String, files: Vec<IncomingFile>) {
        self.sessions
            .write()
            .await
            .insert(token, Arc::new(Session::new(files)));
    }

    /// Closes a session, so a token cannot be replayed after the exchange it
    /// belonged to has ended.
    pub async fn close_session(&self, token: &str) {
        self.sessions.write().await.remove(token);
    }

    /// Stops accepting connections and waits for in-flight requests to finish,
    /// giving up after `grace`.
    ///
    /// Consumes the server, since waiting means owning the serving task. A hard
    /// drop mid-write would leave a partial file with an inaccurate length.
    pub async fn shutdown(self, grace: std::time::Duration) {
        self.handle.graceful_shutdown(Some(grace));
        // Ends once the last connection does. An error here is a panic in the
        // server task, already logged.
        let _ = self.serving.await;
    }
}

/// `HEAD` — how much of this file is already on disk, so the sender can resume.
async fn received_so_far(
    State(state): State<ServerState>,
    Path((token, index)): Path<(String, u32)>,
) -> Response {
    let Some(session) = state.sessions.read().await.get(&token).cloned() else {
        return StatusCode::NOT_FOUND.into_response();
    };
    let Some(counter) = session.received.get(index as usize) else {
        return StatusCode::NOT_FOUND.into_response();
    };

    (
        StatusCode::OK,
        [(RECEIVED_HEADER, counter.load(Ordering::Acquire).to_string())],
    )
        .into_response()
}

/// `PUT` — the body is the file.
async fn receive_blob(
    State(state): State<ServerState>,
    Path((token, index)): Path<(String, u32)>,
    headers: HeaderMap,
    body: Body,
) -> Response {
    let Some(session) = state.sessions.read().await.get(&token).cloned() else {
        // Unknown token: never authorised, or the exchange is over.
        return StatusCode::NOT_FOUND.into_response();
    };

    let Some(file) = session.files.get(index as usize).cloned() else {
        return StatusCode::NOT_FOUND.into_response();
    };
    let counter = &session.received[index as usize];

    let start = start_offset(&headers);
    if start > file.size {
        return (StatusCode::RANGE_NOT_SATISFIABLE, "offset past end of file").into_response();
    }

    let mut progress = ProgressThrottle::new(
        state.events.clone(),
        token.clone(),
        index,
        file.size,
        start,
    );

    match write_body_to_disk(&file, start, body, &mut progress).await {
        Ok(written) => {
            let end = start + written;
            counter.fetch_max(end, Ordering::AcqRel);
            progress.flush();

            if end >= file.size {
                state.events.send(TransferEvent::FileFinished {
                    session: token,
                    index,
                });
            }
            StatusCode::OK.into_response()
        }
        Err(error) => {
            // Whatever reached the disk stays and is reported, for resume.
            let partial = start + progress.transferred().saturating_sub(start);
            counter.fetch_max(partial, Ordering::AcqRel);
            state.events.send(TransferEvent::Failed {
                session: token,
                index,
                partial,
                message: error.to_string(),
            });
            (StatusCode::INTERNAL_SERVER_ERROR, error.to_string()).into_response()
        }
    }
}

async fn write_body_to_disk(
    file: &IncomingFile,
    start: u64,
    body: Body,
    progress: &mut ProgressThrottle,
) -> anyhow::Result<u64> {
    if let Some(parent) = file.destination.parent() {
        tokio::fs::create_dir_all(parent).await?;
    }

    let mut handle = tokio::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(false)
        .open(&file.destination)
        .await?;

    // Claim the full length up front: the allocator places the file in one run,
    // and a receiver low on space finds out now rather than at 90%.
    if start == 0 {
        handle.set_len(file.size).await?;
    }
    handle.seek(std::io::SeekFrom::Start(start)).await?;

    let mut writer = BufWriter::with_capacity(WRITE_BUFFER_BYTES, handle);
    let mut stream = body.into_data_stream();
    let mut written: u64 = 0;

    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;

        // A sender past the size it declared is broken or filling the disk.
        if start + written + chunk.len() as u64 > file.size {
            anyhow::bail!(
                "sender exceeded the {} bytes it declared for {}",
                file.size,
                file.destination.display()
            );
        }

        writer.write_all(&chunk).await?;
        written += chunk.len() as u64;
        progress.advance(chunk.len() as u64);
    }

    writer.flush().await?;
    Ok(written)
}

/// Reads the start offset out of `Content-Range: bytes <start>-<end>/<total>`.
///
/// Absent or unparseable means start at zero; a whole-file PUT is valid.
fn start_offset(headers: &HeaderMap) -> u64 {
    headers
        .get(axum::http::header::CONTENT_RANGE)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("bytes "))
        .and_then(|value| value.split('-').next())
        .and_then(|start| start.trim().parse().ok())
        .unwrap_or(0)
}
