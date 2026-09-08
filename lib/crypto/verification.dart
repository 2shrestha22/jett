import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:jett/crypto/wordlists/verification_words.dart';

/// Words the two people compare. 11 bits each, so 55 bits total.
const int kVerificationWordCount = 5;

/// Hash rounds applied before the words are read off.
const int kVerificationRounds = 100000;

/// [verificationWords], computed off the calling isolate.
///
/// Must stay a top-level function: `Isolate.run` ships the closure's whole
/// enclosing scope, so a closure written at a call site drags along an
/// unsendable object and throws at run time.
Future<List<String>> verificationWordsOffIsolate(
  String fingerprintA,
  String fingerprintB,
) => Isolate.run(() => verificationWords(fingerprintA, fingerprintB));

/// The words two devices show before trusting each other for the first time.
///
/// Sorts the fingerprints so both devices derive the same words without either
/// transmitting them. [rounds] is lowered in tests.
List<String> verificationWords(
  String fingerprintA,
  String fingerprintB, {
  int rounds = kVerificationRounds,
}) {
  final pair = [fingerprintA, fingerprintB]..sort();

  // Bumping the version tag invalidates every existing verification.
  var digest = sha256
      .convert(utf8.encode('jett-verification-v3:${pair[0]}:${pair[1]}'))
      .bytes;
  for (var i = 1; i < rounds; i++) {
    digest = sha256.convert(digest).bytes;
  }

  final words = <String>[];
  var buffer = 0;
  var bits = 0;
  var index = 0;

  // Each 11 bits drawn off the digest index the 2048-word list.
  while (words.length < kVerificationWordCount) {
    buffer = (buffer << 8) | digest[index++];
    bits += 8;
    if (bits >= 11) {
      bits -= 11;
      words.add(kVerificationWords[(buffer >> bits) & 0x7FF]);
    }
  }

  return words;
}
