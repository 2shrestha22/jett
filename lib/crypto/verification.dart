import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:jett/crypto/wordlists/verification_words.dart';

/// How many words the two people compare.
///
/// Five out of 2048 is about 55 bits. That has to carry the whole burden here,
/// because there is no commitment step to limit an attacker to a single guess
/// the way ZRTP and Bluetooth pairing do — the comparison is against long-term
/// keys, so the search can run offline for as long as anyone likes.
const int kVerificationWordCount = 5;

/// Hash rounds applied before the words are read off.
///
/// Costs the person doing the pairing a fraction of a second, once, and costs
/// an attacker the same multiple on every candidate key they try. Signal takes
/// the same approach with its safety numbers. Adding rounds is preferable to
/// adding words: studies of fingerprint comparison find that people make more
/// security-critical mistakes as the string gets longer, so the extra words
/// would partly be paid for in missed mismatches.
const int kVerificationRounds = 100000;

/// [verificationWords], computed off the calling isolate.
///
/// The derivation is deliberately slow, so running it inline freezes the
/// screen just as the prompt is about to appear.
///
/// This has to be its own function. `Isolate.run` ships the closure's entire
/// enclosing scope, not merely what the closure reads, so a closure written
/// at either call site drags along a Completer or a socket and fails at run
/// time with an unsendable-object error. Here the scope holds two strings.
Future<List<String>> verificationWordsOffIsolate(
  String fingerprintA,
  String fingerprintB,
) => Isolate.run(() => verificationWords(fingerprintA, fingerprintB));

/// The words two devices show before trusting each other for the first time.
///
/// Covers both devices. The sender knows its own key and learns the receiver's
/// from the TLS handshake; the receiver knows its own and learns the sender's
/// from the signature on the request. Sorting the pair means both arrive at
/// the same words without either being told them.
///
/// They are never transmitted. Words that travelled between the devices could
/// simply be relayed by the party being guarded against.
///
/// [rounds] exists so tests need not pay the full stretching cost.
List<String> verificationWords(
  String fingerprintA,
  String fingerprintB, {
  int rounds = kVerificationRounds,
}) {
  final pair = [fingerprintA, fingerprintB]..sort();

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
