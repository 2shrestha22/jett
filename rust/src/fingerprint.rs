//! Device fingerprints, computed the same way Jett's Dart side computes them.
//!
//! A fingerprint is the lowercase hex SHA-256 of the DER-encoded
//! SubjectPublicKeyInfo — the whole `SEQUENCE`, tag and length included, not
//! the bare key bits. That is what `basic_utils` hands the Dart code as
//! `tbsCertificate.subjectPublicKeyInfo.bytes`, so the two implementations
//! agree byte for byte. See `lib/crypto/device_keys.dart`.
//!
//! Over the key rather than the certificate, for the reasons set out in that
//! file: certificates get reissued for the same key, and nothing here verifies
//! a self-signature, so hashing the certificate would let an attacker grind a
//! colliding fingerprint by editing fields instead of doing a real keygen.

use sha2::{Digest, Sha256};
use x509_parser::prelude::*;

/// Certificates larger than this are refused before being parsed.
///
/// A stranger's certificate reaches the ASN.1 decoder before anything about
/// that peer is known, so the work done on their behalf is worth bounding. A
/// P-256 certificate is a few hundred bytes. Mirrors `maxCertificatePemBytes`.
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

/// Lowercase, zero-padded hex — the casing `_bytesAsString` produces, and so
/// the casing every stored fingerprint and every verification word is derived
/// from.
fn hex_lower(bytes: &[u8]) -> String {
    use std::fmt::Write;
    bytes.iter().fold(String::with_capacity(bytes.len() * 2), |mut s, b| {
        let _ = write!(s, "{b:02x}");
        s
    })
}

/// Constant-time comparison of two fingerprints.
///
/// Both sides are public values, so this is not guarding a secret. It is here
/// so that a future caller comparing something that *is* secret does not
/// inherit an early-exit `==` by copying this function.
pub fn fingerprints_match(a: &str, b: &str) -> bool {
    let (a, b) = (a.as_bytes(), b.as_bytes());
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}
