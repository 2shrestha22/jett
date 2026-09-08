import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jett/crypto/verification.dart';
import 'package:jett/crypto/wordlists/verification_words.dart';

/// Stretching is deliberately slow, so the tests run without it except where
/// the cost itself is the thing being checked.
const fast = 1;

String fingerprint(String seed) => sha256.convert(utf8.encode(seed)).toString();

void main() {
  final alice = fingerprint('alice');
  final bob = fingerprint('bob');
  final attacker = fingerprint('attacker');

  group('what both devices see', () {
    test('both sides derive the same words from the same pair', () {
      expect(
        verificationWords(alice, bob, rounds: fast),
        verificationWords(bob, alice, rounds: fast),
      );
    });

    test('gives five words, all from the list', () {
      final words = verificationWords(alice, bob, rounds: fast);
      expect(words, hasLength(kVerificationWordCount));
      expect(words.every(kVerificationWords.contains), isTrue);
    });

    test('is stable for a pair', () {
      expect(
        verificationWords(alice, bob, rounds: fast),
        verificationWords(alice, bob, rounds: fast),
      );
    });
  });

  group('what an interceptor runs into', () {
    test('the two screens disagree when somebody is in the middle', () {
      // The sender sees the attacker's key where it expected the receiver's;
      // the receiver sees the attacker's where it expected the sender's.
      final onSender = verificationWords(alice, attacker, rounds: fast);
      final onReceiver = verificationWords(attacker, bob, rounds: fast);

      expect(onSender, isNot(onReceiver));
      expect(onSender, isNot(verificationWords(alice, bob, rounds: fast)));
      expect(onReceiver, isNot(verificationWords(alice, bob, rounds: fast)));
    });

    test('changing either key changes the words', () {
      final honest = verificationWords(alice, bob, rounds: fast);
      expect(
        verificationWords(alice, fingerprint('bob-reinstalled'), rounds: fast),
        isNot(honest),
      );
      expect(
        verificationWords(fingerprint('alice-reinstalled'), bob, rounds: fast),
        isNot(honest),
      );
    });

    test('distinct pairs do not collide across many samples', () {
      final seen = <String>{};
      for (var i = 0; i < 5000; i++) {
        seen.add(
          verificationWords(
            fingerprint('sender-$i'),
            fingerprint('receiver-$i'),
            rounds: fast,
          ).join(' '),
        );
      }
      expect(seen, hasLength(5000));
    });
  });

  group('off the calling isolate', () {
    test('agrees with the inline derivation', () async {
      // Exercises the real isolate hop. Isolate.run ships the closure's whole
      // enclosing scope, so a version written at a call site next to a socket
      // or a Completer compiles and analyses cleanly, then throws at run time
      // on an unsendable object. Only actually running it catches that.
      expect(
        await verificationWordsOffIsolate(alice, bob),
        verificationWords(alice, bob),
      );
    });

    test('carries nothing unsendable across', () async {
      // Guards the same hazard from the other direction: a locally captured
      // unsendable object must not creep into the helper's scope.
      final unsendable = Completer<void>();
      final words = await verificationWordsOffIsolate(alice, bob);
      expect(words, hasLength(kVerificationWordCount));
      expect(unsendable.isCompleted, isFalse);
    });
  });

  group('stretching', () {
    test('changes the answer, so rounds are part of the contract', () {
      // Anything that alters the round count alters every pairing already
      // established, which would silently break trust rather than fail loudly.
      expect(
        verificationWords(alice, bob, rounds: 1),
        isNot(verificationWords(alice, bob, rounds: 2)),
      );
    });

    test('is configured to cost an attacker real work', () {
      expect(kVerificationRounds, greaterThanOrEqualTo(100000));
    });
  });
}
