//! The sending half: reqwest streaming a file straight off disk into a PUT.
//!
//! Symmetric with [`crate::server`] — the body is the file, nothing wraps it.
//! Resume is a `HEAD` for the byte count the peer already holds, then a `PUT`
//! that starts there.

use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use futures_util::StreamExt;
use tokio::io::AsyncSeekExt;
use tokio_util::io::ReaderStream;
use tokio_util::sync::CancellationToken;

use crate::events::{EventSink, ProgressThrottle, TransferEvent};
use crate::protocol::{READ_BUFFER_BYTES, RECEIVED_HEADER};

/// Where the bytes of an outgoing file come from.
#[derive(Debug)]
pub enum FileSource {
    /// A path this process can open for itself.
    Path(PathBuf),

    /// A descriptor the platform layer already opened, whose ownership has
    /// passed to this crate.
    ///
    /// Android only. A `content://` URI names a file inside another app's
    /// provider: it has no path, and only the framework can resolve it. Kotlin
    /// opens it and detaches the descriptor, which arrives here.
    ///
    /// [`OwnedFd`] is what makes that safe. Dropping it closes the descriptor,
    /// so every exit path releases it without a line of code saying so — an
    /// error, a cancellation, or a file never reached because an earlier one
    /// failed.
    ///
    /// [`OwnedFd`]: std::os::fd::OwnedFd
    #[cfg(unix)]
    Descriptor(std::os::fd::OwnedFd),
}

/// A file this device is about to send.
///
/// Not `Clone`: a descriptor has exactly one owner, and duplicating one here
/// would mean two closes of the same number.
#[derive(Debug)]
pub struct OutgoingFile {
    pub source: FileSource,
    pub size: u64,
}

impl FileSource {
    /// Opens the file, consuming the source.
    ///
    /// A descriptor becomes a [`std::fs::File`], which owns it from then on and
    /// closes it when dropped — the same guarantee [`OwnedFd`] was giving.
    ///
    /// [`OwnedFd`]: std::os::fd::OwnedFd
    async fn open(self) -> std::io::Result<tokio::fs::File> {
        match self {
            FileSource::Path(path) => tokio::fs::File::open(path).await,
            #[cfg(unix)]
            FileSource::Descriptor(fd) => Ok(tokio::fs::File::from_std(std::fs::File::from(fd))),
        }
    }

    /// How to name this file when something goes wrong.
    ///
    /// A descriptor has no name — the filename the user picked lives in Dart
    /// and deliberately never crosses into this crate — so the index of the
    /// file within the transfer is the most a message here can say.
    fn describe(&self, index: u32) -> String {
        match self {
            FileSource::Path(path) => path.display().to_string(),
            #[cfg(unix)]
            FileSource::Descriptor(_) => format!("file {index}"),
        }
    }
}

/// Sends every file in `files` to `base_url`, in order, resuming each from
/// whatever the peer already holds.
///
/// Sequential rather than parallel: these are local-network transfers of large
/// files, where one stream already saturates the link and several would only
/// make the progress bars jump around and the disk seek. Parallelism belongs on
/// *ranges of one file* against a distant server, which is a different problem
/// from this one.
pub async fn send_files(
    base_url: &str,
    token: &str,
    peer_fingerprint: &str,
    files: Vec<OutgoingFile>,
    events: EventSink,
    cancel: CancellationToken,
) -> anyhow::Result<()> {
    let tls = crate::tls::client_config(peer_fingerprint)?;
    let client = reqwest::Client::builder()
        .use_preconfigured_tls(tls)
        // Idle sockets to a peer that has gone off the network are worse than
        // useless — the next transfer would spend its first seconds finding out.
        .pool_idle_timeout(std::time::Duration::from_secs(15))
        .build()?;

    // By value, so a file the loop never reaches is dropped with everything
    // else — which for a descriptor is what closes it.
    for (index, file) in files.into_iter().enumerate() {
        if cancel.is_cancelled() {
            events.send(TransferEvent::Cancelled {
                session: token.to_string(),
                index: index as u32,
                partial: 0,
            });
            return Ok(());
        }

        send_one(
            &client,
            base_url,
            token,
            index as u32,
            file,
            &events,
            &cancel,
        )
        .await?;
    }

    Ok(())
}

async fn send_one(
    client: &reqwest::Client,
    base_url: &str,
    token: &str,
    index: u32,
    file: OutgoingFile,
    events: &EventSink,
    cancel: &CancellationToken,
) -> anyhow::Result<()> {
    let url = format!("{}/v2/blob/{}/{}", base_url.trim_end_matches('/'), token, index);

    let resume_from = already_received(client, &url).await.min(file.size);
    if resume_from == file.size {
        // Nothing left to send. Still report completion, or a resumed transfer
        // of an already-finished file would look stuck.
        events.send(TransferEvent::FileFinished {
            session: token.to_string(),
            index,
        });
        return Ok(());
    }

    let name = file.source.describe(index);
    let mut handle = file.source.open().await?;
    // Only a resume seeks. A provider may hand back a pipe, which cannot seek
    // and cannot rewind — so a fresh send still works over one, and only a
    // resumed transfer fails, with the error saying which file.
    if resume_from > 0 {
        handle
            .seek(std::io::SeekFrom::Start(resume_from))
            .await
            .map_err(|e| anyhow::anyhow!("cannot resume {name}: {e}"))?;
    }

    let sent = Arc::new(AtomicU64::new(resume_from));
    let body = counting_body(
        handle,
        ProgressThrottle::new(
            events.clone(),
            token.to_string(),
            index,
            file.size,
            resume_from,
        ),
        sent.clone(),
        cancel.clone(),
    );

    let request = client
        .put(&url)
        .header(
            reqwest::header::CONTENT_RANGE,
            format!("bytes {}-{}/{}", resume_from, file.size.saturating_sub(1), file.size),
        )
        .body(body);

    let outcome = tokio::select! {
        // Biased so that a cancel racing with completion is read as a cancel;
        // the alternative reports success for a transfer the user stopped.
        biased;
        _ = cancel.cancelled() => {
            events.send(TransferEvent::Cancelled {
                session: token.to_string(),
                index,
                partial: sent.load(Ordering::Acquire),
            });
            return Ok(());
        }
        response = request.send() => response,
    };

    match outcome {
        Ok(response) if response.status().is_success() => {
            events.send(TransferEvent::Progress {
                session: token.to_string(),
                index,
                transferred: file.size,
                total: file.size,
            });
            events.send(TransferEvent::FileFinished {
                session: token.to_string(),
                index,
            });
            Ok(())
        }
        Ok(response) => {
            let status = response.status();
            let detail = response.text().await.unwrap_or_default();
            let message = format!("peer refused {name}: {status} {detail}");
            events.send(TransferEvent::Failed {
                session: token.to_string(),
                index,
                partial: sent.load(Ordering::Acquire),
                message: message.clone(),
            });
            anyhow::bail!(message)
        }
        Err(error) => {
            events.send(TransferEvent::Failed {
                session: token.to_string(),
                index,
                partial: sent.load(Ordering::Acquire),
                message: error.to_string(),
            });
            Err(error.into())
        }
    }
}

/// Wraps the file in a body that counts bytes on their way past and stops if
/// the transfer is cancelled.
///
/// Ending the stream early truncates the request, which the peer sees as a
/// short body and treats as a partial transfer — exactly the state resume
/// expects to find.
fn counting_body(
    file: tokio::fs::File,
    progress: ProgressThrottle,
    sent: Arc<AtomicU64>,
    cancel: CancellationToken,
) -> reqwest::Body {
    let reader = ReaderStream::with_capacity(file, READ_BUFFER_BYTES);

    // The throttle rides in the unfold's state rather than the closure: the
    // closure is `FnMut` and would have to give it up on the first call.
    let stream = futures_util::stream::unfold(
        (reader, cancel, progress, sent),
        move |(mut reader, cancel, mut progress, sent)| async move {
            if cancel.is_cancelled() {
                return None;
            }
            match reader.next().await {
                Some(Ok(chunk)) => {
                    progress.advance(chunk.len() as u64);
                    sent.fetch_add(chunk.len() as u64, Ordering::AcqRel);
                    Some((Ok(chunk), (reader, cancel, progress, sent)))
                }
                Some(Err(error)) => Some((Err(error), (reader, cancel, progress, sent))),
                None => {
                    progress.flush();
                    None
                }
            }
        },
    );

    reqwest::Body::wrap_stream(stream)
}

/// Asks the peer how much of this file it already has.
///
/// A peer that cannot answer is treated as having nothing, so a failed probe
/// costs a retransmission rather than a failed transfer.
async fn already_received(client: &reqwest::Client, url: &str) -> u64 {
    let Ok(response) = client.head(url).send().await else {
        return 0;
    };
    if !response.status().is_success() {
        return 0;
    }
    response
        .headers()
        .get(RECEIVED_HEADER)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse().ok())
        .unwrap_or(0)
}
