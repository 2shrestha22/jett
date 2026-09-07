import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jett/crypto/device_keys.dart';

/// The Rust data plane pins peers by fingerprint, so it has to name a key
/// exactly as this side does. Both languages assert against one committed
/// fixture: `rust/tests/dart_interop.rs` reads the same three files.
///
/// If this fails, every stored trust relationship is about to be invalidated —
/// devices would stop recognising peers they have already verified.
void main() {
  const fixtures = 'rust/tests/fixtures';

  test('names the fixture key as the committed fingerprint', () {
    final certificate = File('$fixtures/dart_identity.pem').readAsStringSync();
    final expected = File(
      '$fixtures/dart_identity.fingerprint',
    ).readAsStringSync().trim();

    expect(keyFingerprintOfPem(certificate), expected);
  });

  test('reads the fixture back as a usable identity', () {
    final keys = DeviceKeys.fromPem(
      certificatePem: File('$fixtures/dart_identity.pem').readAsStringSync(),
      privateKeyPem: File('$fixtures/dart_identity.key').readAsStringSync(),
    );

    expect(
      keys.fingerprint,
      File('$fixtures/dart_identity.fingerprint').readAsStringSync().trim(),
    );
  });

  test('reaches the same fingerprint through the DER path', () {
    final certificate = File('$fixtures/dart_identity.pem').readAsStringSync();

    // How a fingerprint arrives from a TLS handshake, versus from storage.
    expect(
      keyFingerprintOfDer(derOfPem(certificate)),
      keyFingerprintOfPem(certificate),
    );
  });
}
