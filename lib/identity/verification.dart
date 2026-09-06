import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:jett/identity/verification_words.dart';

/// How many words are shown. Five words from a 2048-word list is about 55
/// bits, which puts a matching key far out of reach of an attacker generating
/// keypairs until one produces the same words.
const int kVerificationWordCount = 5;

/// The words two devices compare before trusting each other for the first
/// time.
///
/// Derived from the receiving device's certificate fingerprint alone, and
/// deliberately so. The receiver computes it from its own key; the sender
/// computes it from the certificate it was actually shown during the TLS
/// handshake. Anyone sitting in the middle has to present a certificate they
/// hold the private key for, which produces different words on the sender's
/// screen than the receiver is reading out.
///
/// It is never transmitted. A code that travelled between the devices could
/// simply be forwarded by the party being guarded against.
List<String> verificationWords(String receiverFingerprint) {
  final digest = sha256.convert(
    utf8.encode('jett-verification-v1:$receiverFingerprint'),
  );

  final words = <String>[];
  var bitBuffer = 0;
  var bitCount = 0;
  var index = 0;

  while (words.length < kVerificationWordCount) {
    bitBuffer = (bitBuffer << 8) | digest.bytes[index++];
    bitCount += 8;
    if (bitCount >= 11) {
      bitCount -= 11;
      words.add(kVerificationWords[(bitBuffer >> bitCount) & 0x7FF]);
    }
  }

  return words;
}
