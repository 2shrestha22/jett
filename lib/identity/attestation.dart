import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:jett/identity/device_identity.dart';

const _signingAlgorithm = 'SHA-256/ECDSA';

/// What a sender signs to prove which device it is.
///
/// Naming the receiver stops a signature collected by one device being
/// replayed to another, and naming the session stops it being reused against
/// the same device twice.
Uint8List _statement(String sessionId, String receiverFingerprint) =>
    Uint8List.fromList(
      utf8.encode('jett-auth-v1:$sessionId:$receiverFingerprint'),
    );

/// Signs this device's claim to be the one asking, for the receiver it is
/// actually connected to.
///
/// The receiver cannot see a client certificate — Dart will not present one —
/// so this is what gives it a verified sender identity to trust.
String signRequest(String sessionId, String receiverFingerprint) =>
    CryptoUtils.ecSignatureToBase64(
      CryptoUtils.ecSign(
        DeviceIdentity.privateKey,
        _statement(sessionId, receiverFingerprint),
        algorithmName: _signingAlgorithm,
      ),
    );

/// The sender's fingerprint, if [signature] really was made by the holder of
/// [certificatePem] for this session and this device. Null when it was not.
String? verifiedSenderFingerprint({
  required String certificatePem,
  required String signature,
  required String sessionId,
}) {
  try {
    final certificate = X509Utils.x509CertificateFromPem(certificatePem);
    final keyBytes = certificate.tbsCertificate?.subjectPublicKeyInfo.bytes;
    if (keyBytes == null) return null;

    final publicKey = CryptoUtils.ecPublicKeyFromDerBytes(
      _hexToBytes(keyBytes),
    );
    final valid = CryptoUtils.ecVerifyBase64(
      publicKey,
      _statement(sessionId, DeviceIdentity.fingerprint),
      signature,
      algorithm: _signingAlgorithm,
    );

    // The fingerprint only means anything once the signature has shown the
    // sender holds the matching private key; the certificate itself is public
    // and anyone could have copied it.
    return valid ? fingerprintOfCertificate(certificatePem) : null;
  } catch (e, s) {
    log('Could not check the sender attestation', error: e, stackTrace: s);
    return null;
  }
}

Uint8List _hexToBytes(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);
