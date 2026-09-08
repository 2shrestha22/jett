//! Device fingerprints, computed the same way Jett's Dart side computes them.
//!
//! The lowercase hex SHA-256 of the DER-encoded SubjectPublicKeyInfo — the
//! whole `SEQUENCE`, tag and length included, not the bare key bits. Over the
//! key rather than the certificate; see `lib/crypto/device_keys.dart`.

use sha2::{Digest, Sha256};
use x509_parser::prelude::*;

/// Certificates larger than this are refused before being parsed, bounding the
/// work done for an unknown peer. Mirrors `maxCertificatePemBytes`.
pub const MAX_CERTIFICATE_DER_BYTES: usize = 8 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum FingerprintError {
    #[error("certificate is {0} bytes, over the {MAX_CERTIFICATE_DER_BYTES} byte limit")]
    TooLarge(usize),
    #[error("certificate could not be parsed: {0}")]
    Malformed(String),
}

/// The fingerprint of the key carried by a DER certificate.
pub fn fingerprint_of_der(der: &[u8]) -> Result<String, FingerprintError> {
    if der.len() > MAX_CERTIFICATE_DER_BYTES {
        return Err(FingerprintError::TooLarge(der.len()));
    }
    let (_, certificate) =
        X509Certificate::from_der(der).map_err(|e| FingerprintError::Malformed(e.to_string()))?;

    // `.raw` is the SubjectPublicKeyInfo as it appeared on the wire, which is
    // exactly what the Dart side hashes.
    Ok(hex_lower(&Sha256::digest(
        certificate.tbs_certificate.subject_pki.raw,
    )))
}

/// Lowercase, zero-padded hex, matching what `_bytesAsString` produces on the
/// Dart side.
fn hex_lower(bytes: &[u8]) -> String {
    use std::fmt::Write;
    bytes.iter().fold(String::with_capacity(bytes.len() * 2), |mut s, b| {
        let _ = write!(s, "{b:02x}");
        s
    })
}

/// Constant-time comparison of two fingerprints. Both sides are public, so
/// this guards no secret; it is here so a copy of it does not become lax.
pub fn fingerprints_match(a: &str, b: &str) -> bool {
    let (a, b) = (a.as_bytes(), b.as_bytes());
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}
