//! End-to-end tests for the data plane: real TLS, real sockets, real files.
//!
//! Nothing here is mocked. A transfer that works in these tests is a transfer
//! that works between two devices, minus discovery.

use std::path::PathBuf;
use std::time::Duration;

use jett_core::client::{send_files, FileSource, OutgoingFile};
use jett_core::events::{Direction, EventSink, TransferEvent};
use jett_core::fingerprint::fingerprint_of_der;
use jett_core::server::{DataServer, IncomingFile};
use sha2::{Digest, Sha256};
use tokio::sync::mpsc;
use tokio_util::sync::CancellationToken;

struct Identity {
    certificate_pem: String,
    private_key_pem: String,
    fingerprint: String,
}

fn identity() -> Identity {
    let key = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256).unwrap();
    let mut params = rcgen::CertificateParams::new(vec!["jett".to_string()]).unwrap();
    params
        .distinguished_name
        .push(rcgen::DnType::CommonName, "jett");
    let certificate = params.self_signed(&key).unwrap();

    Identity {
        fingerprint: fingerprint_of_der(certificate.der()).unwrap(),
        certificate_pem: certificate.pem(),
        private_key_pem: key.serialize_pem(),
    }
}

fn temp_dir() -> tempfile::TempDir {
    tempfile::tempdir().unwrap()
}

async fn write_file(path: &PathBuf, bytes: &[u8]) {
    tokio::fs::write(path, bytes).await.unwrap();
}

/// Deterministic, incompressible-ish payload — a run of zeroes would hide a
/// bug that writes the right *number* of bytes at the wrong offset.
fn payload(len: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(len);
    let mut state: u32 = 0x9E3779B9;
    while out.len() < len {
        state = state.wrapping_mul(1664525).wrapping_add(1013904223);
        out.extend_from_slice(&state.to_le_bytes());
    }
    out.truncate(len);
    out
}

/// The fingerprint is the SHA-256 of the DER SubjectPublicKeyInfo — the same
/// bytes `basic_utils` hands Jett's Dart side as
/// `tbsCertificate.subjectPublicKeyInfo.bytes`. Checked here against the SPKI
/// rcgen produces independently of any certificate parsing.
#[test]
fn fingerprint_is_sha256_of_the_der_spki() {
    let key = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256).unwrap();
    let params = rcgen::CertificateParams::new(vec!["jett".to_string()]).unwrap();
    let certificate = params.self_signed(&key).unwrap();

    let expected = format!("{:x}", Sha256::digest(key.public_key_der()));
    assert_eq!(fingerprint_of_der(certificate.der()).unwrap(), expected);
    assert_eq!(expected.len(), 64, "lowercase hex, as Dart writes it");
}

#[test]
fn oversized_certificates_are_refused_before_parsing() {
    let huge = vec![0u8; 9 * 1024];
    assert!(fingerprint_of_der(&huge).is_err());
}

#[tokio::test]
async fn transfers_a_file_intact() {
    let receiver = identity();
    let source_dir = temp_dir();
    let destination_dir = temp_dir();

    let contents = payload(6 * 1024 * 1024 + 12345);
    let source = source_dir.path().join("holiday.mp4");
    write_file(&source, &contents).await;
    let destination = destination_dir.path().join("holiday.mp4");

    let (sender, mut events) = mpsc::unbounded_channel();
    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::new(sender, Direction::Receiving),
    )
    .await
    .unwrap();

    server
        .open_session(
            "session-token".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: contents.len() as u64,
            }],
        )
        .await;

    send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "session-token",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await
    .unwrap();

    assert_eq!(
        tokio::fs::read(&destination).await.unwrap(),
        contents,
        "received file differs from the one sent"
    );

    let mut saw_finish = false;
    let mut last_progress = 0;
    while let Ok((direction, event)) = events.try_recv() {
        assert_eq!(direction, Direction::Receiving, "server events are receives");
        match event {
            TransferEvent::FileFinished { index, .. } => {
                assert_eq!(index, 0);
                saw_finish = true;
            }
            TransferEvent::Progress { transferred, .. } => last_progress = transferred,
            other => panic!("unexpected event: {other:?}"),
        }
    }
    assert!(saw_finish, "receiver never reported the file finished");
    assert_eq!(last_progress, contents.len() as u64);
}

#[tokio::test]
async fn resumes_from_what_the_peer_already_holds() {
    let receiver = identity();
    let source_dir = temp_dir();
    let destination_dir = temp_dir();

    let contents = payload(3 * 1024 * 1024);
    let source = source_dir.path().join("archive.zip");
    write_file(&source, &contents).await;
    let destination = destination_dir.path().join("archive.zip");

    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::silent(),
    )
    .await
    .unwrap();
    let base = format!("https://127.0.0.1:{}", server.port());

    // First attempt, cancelled almost immediately: whatever landed on disk is
    // what a resume has to build on.
    server
        .open_session(
            "first".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: contents.len() as u64,
            }],
        )
        .await;

    let cancel = CancellationToken::new();
    let stopper = cancel.clone();
    tokio::spawn(async move {
        tokio::time::sleep(Duration::from_millis(2)).await;
        stopper.cancel();
    });
    let _ = send_files(
        &base,
        "first",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source.clone()),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        cancel,
    )
    .await;

    // Second attempt against a session that reports the partial length, which
    // is what the control channel would set up on retry.
    let partial = tokio::fs::metadata(&destination)
        .await
        .map(|m| m.len())
        .unwrap_or(0);
    server.close_session("first").await;
    server
        .open_session(
            "second".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: contents.len() as u64,
            }],
        )
        .await;

    send_files(
        &base,
        "second",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await
    .unwrap();

    assert_eq!(
        tokio::fs::read(&destination).await.unwrap(),
        contents,
        "resumed file is corrupt (partial was {partial} bytes)"
    );
}

#[tokio::test]
async fn refuses_a_peer_presenting_a_different_key() {
    let receiver = identity();
    let impostor = identity();
    let source_dir = temp_dir();
    let destination_dir = temp_dir();

    let contents = payload(1024);
    let source = source_dir.path().join("secret.txt");
    write_file(&source, &contents).await;

    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::silent(),
    )
    .await
    .unwrap();
    server
        .open_session(
            "session".into(),
            vec![IncomingFile {
                destination: destination_dir.path().join("secret.txt"),
                size: contents.len() as u64,
            }],
        )
        .await;

    // Right address, right token, wrong key. The handshake must not complete.
    let result = send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "session",
        &impostor.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await;

    assert!(result.is_err(), "pinning let an unverified key through");
    assert!(
        !destination_dir.path().join("secret.txt").exists(),
        "bytes reached the disk despite a failed handshake"
    );
}

#[tokio::test]
async fn rejects_an_unknown_session_token() {
    let receiver = identity();
    let source_dir = temp_dir();
    let contents = payload(1024);
    let source = source_dir.path().join("file.bin");
    write_file(&source, &contents).await;

    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::silent(),
    )
    .await
    .unwrap();
    // No session opened at all.

    let result = send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "never-issued",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await;

    assert!(result.is_err(), "an unissued token was accepted");
}

#[tokio::test]
async fn stops_a_sender_that_exceeds_its_declared_size() {
    let receiver = identity();
    let source_dir = temp_dir();
    let destination_dir = temp_dir();

    let contents = payload(512 * 1024);
    let source = source_dir.path().join("liar.bin");
    write_file(&source, &contents).await;
    let destination = destination_dir.path().join("liar.bin");

    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::silent(),
    )
    .await
    .unwrap();

    // The session says 64 KB; the sender will try to push 512 KB.
    let declared = 64 * 1024u64;
    server
        .open_session(
            "session".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: declared,
            }],
        )
        .await;

    let result = send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "session",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await;

    assert!(result.is_err(), "server accepted more than was declared");
    let written = tokio::fs::metadata(&destination).await.unwrap().len();
    assert!(
        written <= declared,
        "wrote {written} bytes for a {declared} byte file"
    );
}

/// The Android path: a file the sender can only reach through a descriptor.
///
/// On a device this descriptor comes from `ContentResolver.openFileDescriptor`
/// for a `content://` URI, which has no path. Here it comes from opening a real
/// file and giving up the path, which exercises the same code — the sender is
/// handed a raw descriptor and nothing else.
#[cfg(unix)]
#[tokio::test]
async fn transfers_a_file_given_only_a_descriptor() {
    use std::os::fd::{FromRawFd, IntoRawFd, OwnedFd};

    let receiver = identity();
    let source_dir = temp_dir();
    let destination_dir = temp_dir();

    let contents = payload(3 * 1024 * 1024 + 77);
    let source = source_dir.path().join("from-a-provider.bin");
    write_file(&source, &contents).await;
    let destination = destination_dir.path().join("landed.bin");

    let (sender, _events) = mpsc::unbounded_channel();
    let server = DataServer::start(
        &receiver.certificate_pem,
        &receiver.private_key_pem,
        0,
        EventSink::new(sender, Direction::Receiving),
    )
    .await
    .unwrap();

    server
        .open_session(
            "session-token".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: contents.len() as u64,
            }],
        )
        .await;

    // Ownership is handed over exactly as `detachFd` hands it over on Android:
    // the descriptor outlives the `File` it came from, and closing it is now
    // somebody else's job.
    let raw = std::fs::File::open(&source).unwrap().into_raw_fd();
    // SAFETY: `into_raw_fd` gave up ownership just above, so nothing else holds
    // or will close this descriptor.
    let owned = unsafe { OwnedFd::from_raw_fd(raw) };

    send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "session-token",
        &receiver.fingerprint,
        vec![OutgoingFile {
            source: FileSource::Descriptor(owned),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await
    .unwrap();

    assert_eq!(
        tokio::fs::read(&destination).await.unwrap(),
        contents,
        "a file sent by descriptor differs from the one on disk"
    );

    // The descriptor the send owned must be closed, not leaked. Reusing the
    // number would be undefined; asking the OS about it is not.
    let still_open = unsafe { libc::fcntl(raw, libc::F_GETFD) } != -1;
    assert!(!still_open, "the descriptor outlived the transfer");
}
