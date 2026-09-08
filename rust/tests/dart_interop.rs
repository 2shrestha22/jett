//! Agreement with the Dart side, checked against a fixture Dart itself minted.
//!
//! Produced by `DeviceKeys.generate()` (see `tool/gen_fixture.dart`) and
//! committed with its expected fingerprint. Both languages assert against that
//! one file.

use jett_core::client::{send_files, FileSource, OutgoingFile};
use jett_core::events::EventSink;
use jett_core::fingerprint::fingerprint_of_der;
use jett_core::server::{DataServer, IncomingFile};
use tokio_util::sync::CancellationToken;

const CERTIFICATE_PEM: &str = include_str!("fixtures/dart_identity.pem");
const PRIVATE_KEY_PEM: &str = include_str!("fixtures/dart_identity.key");
/// What `DeviceKeys.generate()` reported for the certificate above.
const DART_FINGERPRINT: &str = include_str!("fixtures/dart_identity.fingerprint");

fn certificate_der() -> Vec<u8> {
    rustls_pemfile::certs(&mut CERTIFICATE_PEM.as_bytes())
        .next()
        .unwrap()
        .unwrap()
        .to_vec()
}

/// The whole trust model rests on both languages naming a key identically.
#[test]
fn agrees_with_dart_on_the_fingerprint() {
    assert_eq!(
        fingerprint_of_der(&certificate_der()).unwrap(),
        DART_FINGERPRINT.trim(),
        "Rust and Dart disagree about this device's identity"
    );
}

/// Dart writes SEC1 (`EC PRIVATE KEY`) armour, not PKCS#8, and rustls has to
/// serve with it as-is.
#[tokio::test]
async fn serves_tls_with_the_identity_dart_stored() {
    let destination_dir = tempfile::tempdir().unwrap();
    let source_dir = tempfile::tempdir().unwrap();

    let contents = b"the bytes that crossed the boundary".repeat(4096);
    let source = source_dir.path().join("proof.bin");
    tokio::fs::write(&source, &contents).await.unwrap();
    let destination = destination_dir.path().join("proof.bin");

    let server = DataServer::start(CERTIFICATE_PEM, PRIVATE_KEY_PEM, 0, EventSink::silent())
        .await
        .expect("rustls could not load the identity Dart generated");

    server
        .open_session(
            "interop".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: contents.len() as u64,
            }],
        )
        .await;

    // Pinned using the fingerprint Dart computed, as the trust store would.
    send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "interop",
        DART_FINGERPRINT.trim(),
        vec![OutgoingFile {
            source: FileSource::Path(source),
            size: contents.len() as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await
    .unwrap();

    assert_eq!(tokio::fs::read(&destination).await.unwrap(), contents);
}
