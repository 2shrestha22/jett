import 'package:basic_utils/basic_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jett/crypto/device_keys.dart';

/// Issues a second certificate for a key that already has one, which is what
/// happens when a certificate is renewed.
String reissueCertificateFor(DeviceKeys keys) {
  final privateKey = CryptoUtils.ecPrivateKeyFromPem(keys.privateKeyPem);
  final publicKey = ECPublicKey(
    privateKey.parameters!.G * privateKey.d,
    privateKey.parameters,
  );
  final csr = X509Utils.generateEccCsrPem(
    {'CN': 'jett-renewed'},
    privateKey,
    publicKey,
  );
  return X509Utils.generateSelfSignedCertificate(
    privateKey,
    csr,
    3650,
    serialNumber: '99',
  );
}

void main() {
  late DeviceKeys alice;
  late DeviceKeys bob;

  setUpAll(() {
    alice = DeviceKeys.generate();
    bob = DeviceKeys.generate();
  });

  group('identity', () {
    test('each device gets a distinct key', () {
      expect(alice.fingerprint, isNot(bob.fingerprint));
    });

    test('fingerprint is lowercase hex of a SHA-256', () {
      expect(alice.fingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('survives being written out and read back', () {
      final restored = DeviceKeys.fromPem(
        certificatePem: alice.certificatePem,
        privateKeyPem: alice.privateKeyPem,
      );
      expect(restored.fingerprint, alice.fingerprint);
    });

    test('a reissued certificate keeps the same identity', () {
      // The point of fingerprinting the key rather than the certificate:
      // certificates expire, and renewing one must not silently discard every
      // trust relationship the user built.
      final renewed = reissueCertificateFor(alice);
      expect(renewed, isNot(alice.certificatePem));
      expect(keyFingerprintOfPem(renewed), alice.fingerprint);
    });

    test('rejects a certificate that is not one', () {
      expect(keyFingerprintOfPem('not a certificate'), isNull);
      expect(keyFingerprintOfPem(''), isNull);
    });

    test('refuses an oversized certificate without parsing it', () {
      final huge = 'A' * (maxCertificatePemBytes + 1);
      expect(keyFingerprintOfPem(huge), isNull);
    });
  });

  group('signing', () {
    const statement = 'jett-auth-v1:session-7:receiver-fingerprint';

    test('a signature identifies its signer', () {
      final fingerprint = verifiedSignerFingerprint(
        certificatePem: alice.certificatePem,
        signature: alice.sign(statement),
        statement: statement,
      );
      expect(fingerprint, alice.fingerprint);
    });

    test('is deterministic, so no random source can weaken it', () {
      // RFC 6979. Two signatures over the same statement must be identical;
      // if they differ, a nonce is being drawn at random somewhere.
      expect(alice.sign(statement), alice.sign(statement));
    });

    test('will not verify a different statement', () {
      expect(
        verifiedSignerFingerprint(
          certificatePem: alice.certificatePem,
          signature: alice.sign(statement),
          statement: 'jett-auth-v1:session-7:a-different-receiver',
        ),
        isNull,
      );
    });

    test('will not verify against somebody else\'s certificate', () {
      // Certificates are public. Holding one must not let you claim its owner.
      expect(
        verifiedSignerFingerprint(
          certificatePem: bob.certificatePem,
          signature: alice.sign(statement),
          statement: statement,
        ),
        isNull,
      );
    });

    test('rejects rubbish rather than throwing', () {
      expect(
        verifiedSignerFingerprint(
          certificatePem: alice.certificatePem,
          signature: 'not-a-signature',
          statement: statement,
        ),
        isNull,
      );
      expect(
        verifiedSignerFingerprint(
          certificatePem: 'not-a-certificate',
          signature: alice.sign(statement),
          statement: statement,
        ),
        isNull,
      );
    });
  });

  group('DER handling', () {
    test('a certificate read from DER matches the same one read from PEM', () {
      // A certificate arrives as DER from a TLS handshake and as PEM inside a
      // request frame; both routes must reach the same identity.
      final der = derOfPem(alice.certificatePem);
      expect(keyFingerprintOfDer(der), alice.fingerprint);
    });
  });
}
