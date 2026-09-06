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
/// Covers both devices. The sender knows its own key and learns the
/// receiver's from the TLS handshake; the receiver knows its own and learns
/// the sender's from the signature on the request. Sorting the pair means
/// both arrive at the same words without either having to be told them.
///
/// They are never transmitted. Words that travelled between the devices could
/// simply be forwarded by the party being guarded against.
///
/// Anyone sitting in the middle has to use a key it holds, which appears in
/// one side's words and not the other's, so the two screens disagree. It
/// cannot search for a key that makes them agree either: five words out of
/// 2048 is around 55 bits, far past what generating keypairs can cover.
List<String> verificationWords(String fingerprintA, String fingerprintB) {
  final pair = [fingerprintA, fingerprintB]..sort();
  final digest = sha256.convert(
    utf8.encode('jett-verification-v2:${pair[0]}:${pair[1]}'),
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
