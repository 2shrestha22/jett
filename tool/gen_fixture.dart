import 'dart:io';

import 'package:jett/crypto/device_keys.dart';

void main() {
  final keys = DeviceKeys.generate();
  File('rust/tests/fixtures/dart_identity.pem')
      .writeAsStringSync(keys.certificatePem);
  File('rust/tests/fixtures/dart_identity.key')
      .writeAsStringSync(keys.privateKeyPem);
  File('rust/tests/fixtures/dart_identity.fingerprint')
      .writeAsStringSync(keys.fingerprint);
  stdout.writeln(keys.fingerprint);
}
// Run from the project root:
//
//   mise exec -- dart run tool/gen_fixture.dart
//
// Only needed if the fixture is deliberately being replaced. Regenerating it
// changes the expected fingerprint, which is the value both
// `rust/tests/dart_interop.rs` and `test/crypto/fingerprint_interop_test.dart`
// assert against.
