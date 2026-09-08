import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jett/identity/trust_store.dart';
import 'package:path/path.dart' as path;

void main() {
  group('any trust store', () {
    for (final make in <(String, TrustStore Function(Directory))>[
      ('in memory', (_) => InMemoryTrustStore()),
      (
        'file backed',
        (dir) => FileTrustStore(File(path.join(dir.path, 'trusted.json'))),
      ),
    ]) {
      final (label, build) = make;

      group(label, () {
        late Directory dir;
        late TrustStore store;

        setUp(() {
          dir = Directory.systemTemp.createTempSync('jett-trust-test');
          store = build(dir);
        });

        tearDown(() => dir.deleteSync(recursive: true));

        test('knows nothing to begin with', () {
          expect(store.isTrusted('abc'), isFalse);
          expect(store.peers, isEmpty);
        });

        test('remembers a key once it is accepted', () async {
          await store.trust('abc', 'Noble Meadow');
          expect(store.isTrusted('abc'), isTrue);
          expect(store.peers.single.name, 'Noble Meadow');
        });

        test('does not vouch for a key it was never given', () async {
          await store.trust('abc', 'Noble Meadow');
          expect(store.isTrusted('def'), isFalse);
        });

        test('clearing forgets everything', () async {
          await store.trust('abc', 'Noble Meadow');
          await store.trust('def', 'Candid Gull');

          await store.clear();

          expect(store.peers, isEmpty);
          expect(store.isTrusted('abc'), isFalse);
          expect(store.isTrusted('def'), isFalse);
        });

        test('is still usable after being cleared', () async {
          await store.trust('abc', 'Noble Meadow');
          await store.clear();
          await store.trust('ghi', 'Plucky Aspen');

          expect(store.isTrusted('ghi'), isTrue);
          expect(store.peers, hasLength(1));
        });

        test('a device that changes its key is unknown again', () async {
          // Reinstalling produces a new key. There is nothing stable enough to
          // recognise it by, so it must go through verification afresh.
          await store.trust('old-key', 'Noble Meadow');
          expect(store.isTrusted('new-key'), isFalse);
        });
      });
    }
  });

  group('file backed specifically', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('jett-trust-file');
      file = File(path.join(dir.path, 'nested', 'trusted.json'));
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('survives a restart', () async {
      final first = FileTrustStore(file);
      await first.load();
      await first.trust('abc', 'Noble Meadow');

      final second = FileTrustStore(file);
      await second.load();
      expect(second.isTrusted('abc'), isTrue);
      expect(second.peers.single.name, 'Noble Meadow');
    });

    test('creates nothing until something is trusted', () async {
      final store = FileTrustStore(file);
      await store.load();
      expect(file.existsSync(), isFalse);
    });

    test('clearing survives a restart', () async {
      final first = FileTrustStore(file);
      await first.load();
      await first.trust('abc', 'Noble Meadow');
      await first.clear();

      final second = FileTrustStore(file);
      await second.load();
      expect(second.isTrusted('abc'), isFalse);
    });

    test('a corrupt file costs re-verification, not a crash', () async {
      await file.parent.create(recursive: true);
      await file.writeAsString('{ this is not json');

      final store = FileTrustStore(file);
      await store.load();

      expect(store.peers, isEmpty);
      expect(store.isTrusted('abc'), isFalse);
      // and still usable afterwards
      await store.trust('abc', 'Noble Meadow');
      expect(store.isTrusted('abc'), isTrue);
    });
  });
}
