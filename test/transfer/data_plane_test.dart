import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/transfer/data_plane.dart';
import 'package:path/path.dart' as path;

/// The Rust data plane, driven through its Dart wrapper over real TLS sockets.
///
/// Loads the library `cargo build` produced rather than one from an app bundle,
/// because a `flutter test` process has no bundle. Skipped, rather than failed,
/// when that library is absent — a checkout that has not run cargo should not
/// have a red suite.
void main() {
  final root = Directory.current.path;
  final library = debugDataPlaneLibrary(root);

  group(
    'the Rust data plane',
    () {
      late Directory workspace;
      late DeviceKeys receiverKeys;

      setUpAll(() async {
        TestWidgetsFlutterBinding.ensureInitialized();
        HttpOverrides.global = null;
        await DataPlane.instance.initialize(library: library);
      });

      setUp(() {
        workspace = Directory.systemTemp.createTempSync('jett-data-plane');
        receiverKeys = DeviceKeys.generate();
      });

      tearDown(() async {
        await DataPlane.instance.stopServer();
        workspace.deleteSync(recursive: true);
      });

      File sourceOf(String name, int length) =>
          File(path.join(workspace.path, name))..writeAsBytesSync(
            List<int>.generate(length, (i) => (i * 31 + 7) & 0xFF),
          );

      test('loads the native library', () {
        expect(
          DataPlane.instance.available,
          isTrue,
          reason: 'the library at rust/target exists but would not load',
        );
      });

      test('carries a file end to end, pinned to the receiver key', () async {
        final source = sourceOf('holiday.mp4', 4 * 1024 * 1024 + 11);
        final sent = source.readAsBytesSync();
        final destination = path.join(workspace.path, 'received.mp4');

        final port = await DataPlane.instance.startServer(
          certificatePem: receiverKeys.certificatePem,
          privateKeyPem: receiverKeys.privateKeyPem,
        );
        expect(port, isNotNull);
        expect(port, greaterThan(0));

        final opened = await DataPlane.instance.openSession(
          token: 'session-token',
          destinations: [(destination: destination, size: sent.length)],
        );
        expect(opened, isTrue);

        final finished = DataPlane.instance.events
            .firstWhere((e) => e is DataPlaneFileFinished)
            .timeout(const Duration(seconds: 30));

        final task = DataPlane.instance.startSend(
          host: '127.0.0.1',
          port: port!,
          token: 'session-token',
          peerFingerprint: receiverKeys.fingerprint,
          files: [(source: NativePath(source.path), size: sent.length)],
        );
        expect(task, isNotNull);

        await finished;
        expect(File(destination).readAsBytesSync(), sent);
      });

      test('reports progress without an event per chunk', () async {
        final source = sourceOf('big.bin', 8 * 1024 * 1024);
        final destination = path.join(workspace.path, 'big-received.bin');

        final port = await DataPlane.instance.startServer(
          certificatePem: receiverKeys.certificatePem,
          privateKeyPem: receiverKeys.privateKeyPem,
        );
        await DataPlane.instance.openSession(
          token: 'progress',
          destinations: [(destination: destination, size: 8 * 1024 * 1024)],
        );

        final progress = <DataPlaneProgress>[];
        final subscription = DataPlane.instance.events
            .where((e) => e is DataPlaneProgress)
            .cast<DataPlaneProgress>()
            .listen(progress.add);

        final finished = DataPlane.instance.events
            .firstWhere((e) => e is DataPlaneFileFinished)
            .timeout(const Duration(seconds: 30));

        DataPlane.instance.startSend(
          host: '127.0.0.1',
          port: port!,
          token: 'progress',
          peerFingerprint: receiverKeys.fingerprint,
          files: [(source: NativePath(source.path), size: 8 * 1024 * 1024)],
        );
        await finished;
        await subscription.cancel();

        expect(progress, isNotEmpty, reason: 'no progress was reported at all');
        // Throttled to roughly ten a second per file. At 8 MiB over loopback
        // an event per chunk would be hundreds; this is the FFI traffic the
        // design exists to avoid.
        expect(
          progress.length,
          lessThan(60),
          reason: 'progress is crossing the boundary far too often',
        );
        expect(progress.last.total, 8 * 1024 * 1024);
      });

      test('refuses a peer whose key is not the verified one', () async {
        final impostor = DeviceKeys.generate();
        final source = sourceOf('secret.txt', 4096);
        final destination = path.join(workspace.path, 'secret-received.txt');

        final port = await DataPlane.instance.startServer(
          certificatePem: receiverKeys.certificatePem,
          privateKeyPem: receiverKeys.privateKeyPem,
        );
        await DataPlane.instance.openSession(
          token: 'pinned',
          destinations: [(destination: destination, size: 4096)],
        );

        final failed = DataPlane.instance.events
            .firstWhere((e) => e is DataPlaneFailed)
            .timeout(const Duration(seconds: 30));

        DataPlane.instance.startSend(
          host: '127.0.0.1',
          port: port!,
          token: 'pinned',
          peerFingerprint: impostor.fingerprint,
          files: [(source: NativePath(source.path), size: 4096)],
        );

        expect(await failed, isA<DataPlaneFailed>());
        expect(
          File(destination).existsSync(),
          isFalse,
          reason: 'bytes landed despite a failed handshake',
        );
      });

      test('refuses a token the receiver never issued', () async {
        final source = sourceOf('a.bin', 4096);
        final port = await DataPlane.instance.startServer(
          certificatePem: receiverKeys.certificatePem,
          privateKeyPem: receiverKeys.privateKeyPem,
        );
        // No session opened.

        final failed = DataPlane.instance.events
            .firstWhere((e) => e is DataPlaneFailed)
            .timeout(const Duration(seconds: 30));

        DataPlane.instance.startSend(
          host: '127.0.0.1',
          port: port!,
          token: 'never-issued',
          peerFingerprint: receiverKeys.fingerprint,
          files: [(source: NativePath(source.path), size: 4096)],
        );

        expect(await failed, isA<DataPlaneFailed>());
      });
    },
    skip: library == null
        ? 'no data plane library built; run `cargo build --release` in rust/'
        : null,
  );
}
