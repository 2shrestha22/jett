//! TLS for the data plane, using the identity Dart already minted.
//!
//! The key never leaves the app's support directory in a form this crate
//! chooses: Dart owns `DeviceIdentity`, and hands the PEMs across the FFI
//! boundary at server start. There is deliberately no keygen here — two
//! implementations of "what is this device called" is exactly the kind of
//! divergence that silently breaks every stored trust relationship.

use std::sync::Arc;

use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::{ring, CryptoProvider, WebPkiSupportedAlgorithms};
use rustls::pki_types::{CertificateDer, PrivateKeyDer, ServerName, UnixTime};
use rustls::{ClientConfig, DigitallySignedStruct, ServerConfig, SignatureScheme};

use crate::fingerprint::{fingerprint_of_der, fingerprints_match};

/// `ring` rather than the newer `aws-lc-rs` default.
///
/// Both are sound; `ring` is the one that cross-compiles to the five targets
/// Jett ships to without dragging cmake and a C toolchain into the Android and
/// iOS builds. Avoiding that is most of the reason this port is in Rust at all.
pub fn provider() -> Arc<CryptoProvider> {
    Arc::new(ring::default_provider())
}

#[derive(Debug, thiserror::Error)]
pub enum TlsError {
    #[error("certificate PEM held no certificate")]
    NoCertificate,
    #[error("private key PEM held no key")]
    NoPrivateKey,
    #[error("PEM could not be read: {0}")]
    BadPem(String),
    #[error("rustls rejected the identity: {0}")]
    Rejected(String),
}

/// Server-side TLS from the PEMs Dart stores in `identity/`.
///
/// Accepts SEC1 (`EC PRIVATE KEY`) or PKCS#8 (`PRIVATE KEY`) armour, because
/// which one comes out of `CryptoUtils.encodeEcPrivateKeyToPem` is a detail of
/// a package on the other side of the boundary and not worth coupling to.
pub fn server_config(certificate_pem: &str, private_key_pem: &str) -> Result<ServerConfig, TlsError> {
    let certificates = rustls_pemfile::certs(&mut certificate_pem.as_bytes())
        .collect::<Result<Vec<_>, _>>()
        .map_err(|e| TlsError::BadPem(e.to_string()))?;
    if certificates.is_empty() {
        return Err(TlsError::NoCertificate);
    }

    let key = rustls_pemfile::private_key(&mut private_key_pem.as_bytes())
        .map_err(|e| TlsError::BadPem(e.to_string()))?
        .ok_or(TlsError::NoPrivateKey)?;

    // No client certificates: the sender proves who it is by signing an
    // attestation on the control channel, and carries the resulting session
    // token here. Requiring mTLS as well would mean a second, differently
    // shaped answer to a question already answered.
    ServerConfig::builder_with_provider(provider())
        .with_safe_default_protocol_versions()
        .map_err(|e| TlsError::Rejected(e.to_string()))?
        .with_no_client_auth()
        .with_single_cert(certificates, PrivateKeyDer::from(key))
        .map_err(|e| TlsError::Rejected(e.to_string()))
}

/// Client-side TLS that trusts exactly one key: the one whose fingerprint the
/// user already verified.
pub fn client_config(expected_fingerprint: &str) -> Result<ClientConfig, TlsError> {
    let provider = provider();
    let verifier = PinnedFingerprint {
        expected: expected_fingerprint.to_ascii_lowercase(),
        algorithms: provider.signature_verification_algorithms,
    };

    ClientConfig::builder_with_provider(provider)
        .with_safe_default_protocol_versions()
        .map_err(|e| TlsError::Rejected(e.to_string()))?
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(verifier))
        .with_no_client_auth()
        .pipe(Ok)
}

/// Verifies the peer by key fingerprint instead of by chain and hostname.
///
/// There is no certificate authority on a local network and no name worth
/// checking — peers are found by broadcast and addressed by whatever IP the
/// router handed out this morning. What the user actually confirmed, by
/// reading verification words aloud, was a *key*. So that is what gets checked
/// here, and a chain or a hostname would only be theatre.
///
/// This is `dangerous()` in rustls' vocabulary because it replaces the web PKI.
/// It is not lax: an unpinned peer, or the right peer presenting a different
/// key, is rejected outright.
#[derive(Debug)]
struct PinnedFingerprint {
    expected: String,
    algorithms: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for PinnedFingerprint {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        let presented = fingerprint_of_der(end_entity)
            .map_err(|e| rustls::Error::General(format!("peer certificate unusable: {e}")))?;

        if fingerprints_match(&presented, &self.expected) {
            Ok(ServerCertVerified::assertion())
        } else {
            // Deliberately vague to the peer, specific in the log: a device
            // that answers on the right address with the wrong key is either a
            // reinstall or an impersonation, and the user needs to re-verify
            // either way.
            Err(rustls::Error::General(format!(
                "peer key {presented} is not the verified key {}",
                self.expected
            )))
        }
    }

    // Signature checking is still the real thing from the provider — pinning
    // decides *which* key is acceptable, not whether the handshake has to prove
    // possession of it. Skipping these would let anyone replay a copied
    // certificate, which is public.
    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls12_signature(message, cert, dss, &self.algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// Tiny helper so the builder chain above reads top-to-bottom.
trait Pipe: Sized {
    fn pipe<T>(self, f: impl FnOnce(Self) -> T) -> T {
        f(self)
    }
}
impl<T> Pipe for T {}
