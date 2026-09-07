//! What the data plane actually moves, end to end.
//!
//! Deliberately the *whole* path — TLS handshake, HTTP framing, socket, and a
//! real write to a real file — because that is what Jett does and the
//! interesting number is not how fast a buffer can be memcpy'd. Comparable to
//! `layerbench.dart`, which measures Dart's raw TCP and raw TLS ceilings.
//!
//! Ignored by default: it is a measurement, not an assertion, and loopback
//! numbers on a busy CI box mean nothing. Run it deliberately:
//!
//!   cargo test --release --test throughput -- --ignored --nocapture

use std::time::Instant;

use jett_core::client::{send_files, OutgoingFile};
use jett_core::events::EventSink;
use jett_core::fingerprint::fingerprint_of_der;
use jett_core::server::{DataServer, IncomingFile};
use tokio_util::sync::CancellationToken;

const PAYLOAD_BYTES: usize = 512 * 1024 * 1024;

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
#[ignore]
async fn measures_end_to_end_throughput() {
    let key = rcgen::KeyPair::generate_for(&rcgen::PKCS_ECDSA_P256_SHA256).unwrap();
    let certificate = rcgen::CertificateParams::new(vec!["jett".to_string()])
        .unwrap()
        .self_signed(&key)
        .unwrap();
    let fingerprint = fingerprint_of_der(certificate.der()).unwrap();

    let source_dir = tempfile::tempdir().unwrap();
    let destination_dir = tempfile::tempdir().unwrap();
    let source = source_dir.path().join("payload.bin");
    let destination = destination_dir.path().join("payload.bin");

    // Written once, outside the timed section, and large enough that it does
    // not simply sit in the page cache on a small machine.
    tokio::fs::write(&source, vec![0x5Au8; PAYLOAD_BYTES])
        .await
        .unwrap();

    let server = DataServer::start(
        &certificate.pem(),
        &key.serialize_pem(),
        0,
        EventSink::silent(),
    )
    .await
    .unwrap();
    server
        .open_session(
            "bench".into(),
            vec![IncomingFile {
                destination: destination.clone(),
                size: PAYLOAD_BYTES as u64,
            }],
        )
        .await;

    let started = Instant::now();
    send_files(
        &format!("https://127.0.0.1:{}", server.port()),
        "bench",
        &fingerprint,
        &[OutgoingFile {
            source,
            size: PAYLOAD_BYTES as u64,
        }],
        EventSink::silent(),
        CancellationToken::new(),
    )
    .await
    .unwrap();
    let elapsed = started.elapsed();

    assert_eq!(
        tokio::fs::metadata(&destination).await.unwrap().len(),
        PAYLOAD_BYTES as u64
    );

    let megabytes = PAYLOAD_BYTES as f64 / (1024.0 * 1024.0);
    println!(
        "\n  jett data plane (TLS + HTTP + disk)   {:.0} MB/s   [{:.2}s for {:.0} MiB]\n",
        megabytes / elapsed.as_secs_f64(),
        elapsed.as_secs_f64(),
        megabytes
    );
}
