import 'dart:convert';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// This device's long-lived cryptographic identity.
///
/// Generated once on first run and kept for the life of the install. The
/// [fingerprint] is what identifies this device to peers: it survives
/// restarts and address changes, which an IP does not.
///
/// The key sits in the app's private support directory rather than the
/// platform keychain, which keeps the app free of native storage plugins and
/// per-platform entitlements. Anything able to read it can already read the
/// files being transferred.
class DeviceIdentity {
  const DeviceIdentity._();

  static const _certFileName = 'cert.pem';
  static const _keyFileName = 'key.pem';
  static const _validityDays = 3650;

  static late final String certificatePem;
  static late final String privateKeyPem;

  /// SHA-256 of the certificate's DER encoding, lowercase hex.
  static late final String fingerprint;

  static Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(path.join(support.path, 'identity'));
    final certFile = File(path.join(directory.path, _certFileName));
    final keyFile = File(path.join(directory.path, _keyFileName));

    if (await certFile.exists() && await keyFile.exists()) {
      certificatePem = await certFile.readAsString();
      privateKeyPem = await keyFile.readAsString();
    } else {
      await directory.create(recursive: true);
      final generated = _generate();
      // key first: a crash between the two writes leaves no certificate, and
      // the next run regenerates both rather than pairing mismatched halves
      await keyFile.writeAsString(generated.keyPem);
      await certFile.writeAsString(generated.certPem);
      certificatePem = generated.certPem;
      privateKeyPem = generated.keyPem;
    }

    fingerprint = fingerprintOfCertificate(certificatePem);
  }

  static ({String certPem, String keyPem}) _generate() {
    // P-256 rather than RSA: generating an RSA key can stall first launch on
    // a phone for seconds, and this one is generated in the foreground.
    final pair = CryptoUtils.generateEcKeyPair(curve: 'prime256v1');
    final privateKey = pair.privateKey as ECPrivateKey;
    final publicKey = pair.publicKey as ECPublicKey;

    final csr = X509Utils.generateEccCsrPem(
      {'CN': 'jett'},
      privateKey,
      publicKey,
    );
    final certificate = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      _validityDays,
    );

    return (
      certPem: certificate,
      keyPem: CryptoUtils.encodeEcPrivateKeyToPem(privateKey),
    );
  }
}

/// SHA-256 over the certificate's DER bytes, lowercase hex.
///
/// Matches what a peer computes from the certificate it is offered during a
/// TLS handshake, so the two can be compared directly.
String fingerprintOfCertificate(String certificatePem) {
  final body = certificatePem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s'), '');
  return sha256.convert(base64.decode(body)).toString();
}
