import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/identity/device_identity.dart';
import 'package:jett/identity/trust_store.dart';
import 'package:jett/model/device.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/client.dart';
import 'package:jett/transfer/data_plane.dart';
import 'package:jett/transfer/protocol.dart';
import 'package:jett/transfer/server.dart';
import 'package:jett/utils/package_info.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The transfer path end to end, over real TLS sockets.
///
/// One file rather than several: `flutter test` runs files concurrently, and
/// the server binds the fixed [kTcpPort].

/// Points `getSavePath()` at a directory the test owns.
class _FakeDownloads extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakeDownloads(this.root);
  final String root;

  @override
  Future<String?> getDownloadsPath() async => root;
}

void main() {
  late Directory workspace;
  late String savePath;
  late DeviceKeys senderKeys;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding's mock HttpClient answers every request itself; these
    // tests want real sockets.
    HttpOverrides.global = null;
    // getSavePath() branches on the platform; the desktop branch is the one
    // that asks for a downloads directory, which is what the fake provides.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    PackageInfoHelper.appName = 'JettTest';
    // Debug builds drop received bytes by default; these tests are about what
    // reaches the disk.
    disableFileWrite = false;

    workspace = Directory.systemTemp.createTempSync('jett-transfer-test');
    PathProviderPlatform.instance = _FakeDownloads(workspace.path);
    savePath = path.join(workspace.path, 'JettTest');

    deviceIdentity = DeviceIdentity(DeviceKeys.generate());
    trustStore = InMemoryTrustStore();
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
    workspace.deleteSync(recursive: true);
  });

  File sourceFile(String name, int length) => File(
    path.join(workspace.path, name),
  )..writeAsBytesSync(List<int>.generate(length, (i) => (i * 31 + 7) & 0xFF));

  List<int> payload(int length) =>
      List<int>.generate(length, (i) => (i * 31 + 7) & 0xFF);

  Device peer() => const Device(
    ipAddress: '127.0.0.1',
    name: 'Test Receiver',
    protocolVersion: kProtocolVersion,
  );

  // ---------------------------------------------------------------------
  // Receiving: the server driven directly, so each refusal can be provoked.
  // ---------------------------------------------------------------------
  group('receiving', () {
    setUpAll(() async {
      await server.start();
      Directory(savePath).createSync(recursive: true);
    });

    tearDownAll(() => server.close());

    setUp(() => senderKeys = DeviceKeys.generate());

    tearDown(() {
      server.reset();
      for (final entry in Directory(savePath).listSync()) {
        entry.deleteSync(recursive: true);
      }
    });

    /// Opens the control channel and gets as far as an accepted transfer,
    /// returning the receiver's acceptance and the frames still to come.
    Future<(AcceptedFrame, Stream<ControlMessage>, HttpClient)> accepted(
      String session,
      List<OfferedFile> files,
    ) async {
      final httpClient = HttpClient(
        context: SecurityContext(withTrustedRoots: false),
      )..badCertificateCallback = (_, _, _) => true;

      final socket = IOWebSocketChannel(
        await WebSocket.connect(
          'wss://127.0.0.1:$kTcpPort/ws',
          customClient: httpClient,
        ),
      );
      final frames = socket.stream
          .map((raw) => ControlMessage.fromJson(raw as String))
          .asBroadcastStream();

      socket.sink.add(
        RequestFrame(
          sessionId: session,
          senderName: 'Test Sender',
          files: files,
          totalSize: files.fold(0, (sum, file) => sum + file.size),
          dataPlaneVersion: kDataPlaneVersion,
          senderCertificate: senderKeys.certificatePem,
          signature: senderKeys.sign(
            attestationStatement(session, deviceIdentity.fingerprint),
          ),
        ).toJson(),
      );

      final answer = frames.firstWhere((f) => f is AcceptedFrame);

      // The user tapping accept. Waits for the request to have landed, which
      // is what puts the server into TransferWaiting.
      await server.transferState.firstWhere((s) => s is TransferWaiting);
      server.acceptRequest();

      return (await answer as AcceptedFrame, frames, httpClient);
    }

    Future<http.StreamedResponse> putBlob(
      HttpClient httpClient,
      String session,
      int index,
      List<int> body,
    ) async {
      final request = http.StreamedRequest(
        'PUT',
        Uri.parse('https://127.0.0.1:$kTcpPort/v2/blob/$session/$index'),
      )..contentLength = body.length;
      unawaited(
        request.sink
            .addStream(Stream.value(body))
            .whenComplete(request.sink.close),
      );
      final response = await IOClient(httpClient).send(request);
      await response.stream.drain<void>();
      return response;
    }

    test('settles on the raw-body path when both sides can use it', () async {
      final (accept, _, client) = await accepted('s-negotiate', [
        const OfferedFile(name: 'a.bin', size: 4),
      ]);
      expect(accept.dataPlaneVersion, kDataPlaneVersion);
      client.close(force: true);
    });

    test('refuses a sender that can only do multipart', () async {
      final httpClient = HttpClient(
        context: SecurityContext(withTrustedRoots: false),
      )..badCertificateCallback = (_, _, _) => true;

      final socket = IOWebSocketChannel(
        await WebSocket.connect(
          'wss://127.0.0.1:$kTcpPort/ws',
          customClient: httpClient,
        ),
      );
      final frames = socket.stream
          .map((raw) => ControlMessage.fromJson(raw as String))
          .asBroadcastStream();
      final answer = frames.first;

      socket.sink.add(
        RequestFrame(
          sessionId: 's-legacy',
          senderName: 'Test Sender',
          files: const [OfferedFile(name: 'a.bin', size: 4)],
          totalSize: 4,
          dataPlaneVersion: 1,
          senderCertificate: senderKeys.certificatePem,
          signature: senderKeys.sign(
            attestationStatement('s-legacy', deviceIdentity.fingerprint),
          ),
        ).toJson(),
      );

      // Refused outright, without ever asking the user.
      expect(
        await answer,
        isA<DeclinedFrame>().having(
          (f) => f.reason,
          'reason',
          TransferFailure.versionMismatch,
        ),
      );
      expect(server.transferState.value, isA<TransferIdle>());
      httpClient.close(force: true);
    });

    test('writes a received file byte for byte', () async {
      final bytes = payload(3 * 1024 * 1024 + 17);
      final (_, frames, client) = await accepted('s-write', [
        OfferedFile(name: 'holiday.mp4', size: bytes.length),
      ]);

      final done = frames.firstWhere((f) => f is CompletedFrame);
      final response = await putBlob(client, 's-write', 0, bytes);

      expect(response.statusCode, 200);
      await done;
      expect(
        File(path.join(savePath, 'holiday.mp4')).readAsBytesSync(),
        bytes,
        reason: 'the file on disk differs from the one sent',
      );
      client.close(force: true);
    });

    test('completes only once every offered file has arrived', () async {
      final first = payload(1024);
      final second = payload(2048);
      final (_, frames, client) = await accepted('s-two', [
        OfferedFile(name: 'one.bin', size: first.length),
        OfferedFile(name: 'two.bin', size: second.length),
      ]);

      var completed = false;
      unawaited(
        frames.firstWhere((f) => f is CompletedFrame).then((_) {
          completed = true;
        }),
      );

      expect((await putBlob(client, 's-two', 0, first)).statusCode, 200);
      // One of two in: the transfer is not over, whatever that response said.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(completed, isFalse, reason: 'completed before the second file');

      expect((await putBlob(client, 's-two', 1, second)).statusCode, 200);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(completed, isTrue);

      expect(File(path.join(savePath, 'one.bin')).readAsBytesSync(), first);
      expect(File(path.join(savePath, 'two.bin')).readAsBytesSync(), second);
      client.close(force: true);
    });

    test('refuses a sender that exceeds the size it offered', () async {
      // Offers 1 KB, sends 64 KB.
      final (_, _, client) = await accepted('s-liar', [
        const OfferedFile(name: 'liar.bin', size: 1024),
      ]);

      // The receiver stops reading at the offered size, so the sender either
      // reads a 500 or fails its own write. Both mean refused.
      int? status;
      try {
        status = (await putBlob(
          client,
          's-liar',
          0,
          payload(64 * 1024),
        )).statusCode;
      } on http.ClientException {
        status = null;
      }
      expect(status, isNot(200));

      // The refusal can reach the sender before the receiver has finished
      // tidying up, so wait for it to publish an ending.
      final ending = await server.transferState.firstWhere((s) => s.isTerminal);
      expect(ending, isA<TransferFailed>());
      expect(
        File(path.join(savePath, 'liar.bin')).existsSync(),
        isFalse,
        reason: 'an oversized upload was left on disk',
      );
      client.close(force: true);
    });

    test('refuses a body that stops short of what was offered', () async {
      final (_, _, client) = await accepted('s-short', [
        const OfferedFile(name: 'short.bin', size: 8192),
      ]);

      final response = await putBlob(client, 's-short', 0, payload(100));

      expect(response.statusCode, isNot(200));
      final ending = await server.transferState.firstWhere((s) => s.isTerminal);
      expect(ending, isA<TransferFailed>());
      expect(
        File(path.join(savePath, 'short.bin')).existsSync(),
        isFalse,
        reason: 'a truncated file was left looking complete',
      );
      client.close(force: true);
    });

    test('refuses an index that was never offered', () async {
      final (_, _, client) = await accepted('s-index', [
        const OfferedFile(name: 'a.bin', size: 4),
      ]);

      expect(
        (await putBlob(client, 's-index', 1, [1, 2, 3, 4])).statusCode,
        404,
      );
      expect(
        (await putBlob(client, 's-index', -1, [1, 2, 3, 4])).statusCode,
        404,
      );
      client.close(force: true);
    });

    test('refuses a session that was never accepted here', () async {
      final (_, _, client) = await accepted('s-real', [
        const OfferedFile(name: 'a.bin', size: 4),
      ]);

      expect(
        (await putBlob(client, 's-forged', 0, [1, 2, 3, 4])).statusCode,
        403,
        reason: 'a token this device never issued was honoured',
      );
      client.close(force: true);
    });

    test('keeps a sender-chosen name inside the download directory', () async {
      // Still the sender's to choose, so it still has to be defanged.
      final bytes = payload(64);
      final (_, frames, client) = await accepted('s-escape', [
        OfferedFile(name: '../../escaped.bin', size: bytes.length),
      ]);

      final done = frames.firstWhere((f) => f is CompletedFrame);
      expect((await putBlob(client, 's-escape', 0, bytes)).statusCode, 200);
      await done;

      expect(File(path.join(savePath, 'escaped.bin')).existsSync(), isTrue);
      expect(
        File(path.join(workspace.path, '..', 'escaped.bin')).existsSync(),
        isFalse,
        reason: 'a sender escaped the download directory',
      );
      client.close(force: true);
    });
  });

  // ---------------------------------------------------------------------
  // Sending: the real client, against a real receiver and against an old one.
  // ---------------------------------------------------------------------
  group('sending', () {
    tearDown(() {
      client.reset();
      server.reset();
    });

    group('to a receiver that speaks the raw-body path', () {
      setUp(() async {
        await server.start();
        Directory(savePath).createSync(recursive: true);
      });

      tearDown(() => server.close());

      test('the whole loop moves a file intact', () async {
        final source = sourceFile('loop.bin', 2 * 1024 * 1024 + 9);
        final sent = source.readAsBytesSync();

        // The receiver accepts as soon as it is asked; there is nobody to tap.
        final accepted = server.transferState
            .firstWhere((s) => s is TransferWaiting)
            .then((_) => server.acceptRequest());

        final started = client.startUpload(
          [FileResource(source.path)],
          peer(),
          (_, _, _) async => true,
        );
        expect(started, isTrue);
        await accepted;

        final ending = await client.transferState.firstWhere(
          (s) => s.isTerminal,
        );
        expect(
          ending,
          isA<TransferCompleted>(),
          reason: 'the sender did not see the transfer through',
        );
        expect(File(path.join(savePath, 'loop.bin')).readAsBytesSync(), sent);
      });

      test('several files all arrive', () async {
        final first = sourceFile('first.bin', 4096);
        final second = sourceFile('second.bin', 8192);

        final accepted = server.transferState
            .firstWhere((s) => s is TransferWaiting)
            .then((_) => server.acceptRequest());

        client.startUpload(
          [FileResource(first.path), FileResource(second.path)],
          peer(),
          (_, _, _) async => true,
        );
        await accepted;

        final ending = await client.transferState.firstWhere(
          (s) => s.isTerminal,
        );
        expect(ending, isA<TransferCompleted>());
        expect(
          File(path.join(savePath, 'first.bin')).readAsBytesSync(),
          first.readAsBytesSync(),
        );
        expect(
          File(path.join(savePath, 'second.bin')).readAsBytesSync(),
          second.readAsBytesSync(),
        );
      });
    });

    group('to a receiver that only knows multipart', () {
      late HttpServer stub;
      late Completer<String> reached;

      setUp(() async {
        reached = Completer<String>();

        // A build predating the raw-body path: accepts with dataPlaneVersion 1.
        final router = Router()
          ..get('/ws', (Request request) {
            return webSocketHandler((WebSocketChannel socket, _) {
              socket.stream.listen((raw) {
                final frame = ControlMessage.fromJson(raw as String);
                if (frame is! RequestFrame) return;
                socket.sink.add(
                  AcceptedFrame(
                    sessionId: frame.sessionId,
                    dataPlaneVersion: 1,
                  ).toJson(),
                );
              });
            })(request);
          })
          ..put('/v2/blob/<session>/<index>', (
            Request request,
            String _,
            String _,
          ) {
            // Reaching this means the sender sent v2 bytes to a v1 receiver.
            if (!reached.isCompleted) reached.complete('RAW-BODY');
            return Response.ok('');
          });

        stub = await shelf_io.serve(
          router.call,
          InternetAddress.loopbackIPv4,
          kTcpPort,
          securityContext: SecurityContext(withTrustedRoots: false)
            ..useCertificateChainBytes(
              utf8.encode(deviceIdentity.certificatePem),
            )
            ..usePrivateKeyBytes(utf8.encode(deviceIdentity.privateKeyPem)),
        );
      });

      tearDown(() => stub.close(force: true));

      test('the sender gives up rather than sending bytes it cannot', () async {
        final source = sourceFile('fallback.bin', 16 * 1024);

        client.startUpload(
          [FileResource(source.path)],
          peer(),
          (_, _, _) async => true,
        );

        final ending = await client.transferState.firstWhere(
          (s) => s.isTerminal,
        );
        expect(
          ending,
          isA<TransferFailed>().having(
            (s) => s.reason,
            'reason',
            TransferFailure.versionMismatch,
          ),
        );
        expect(
          reached.isCompleted,
          isFalse,
          reason: 'v2 bytes were sent to a receiver that asked for multipart',
        );
      });
    });

    // Last, deliberately: everything above runs with the native data plane
    // uninitialised, so the Dart handlers carry the bytes. Groups run in
    // order, so both paths are covered without a seam in the app code.
    group(
      'with the native data plane',
      () {
        setUpAll(
          () => DataPlane.instance.initialize(
            library: debugDataPlaneLibrary(Directory.current.path),
          ),
        );

        setUp(() async {
          await server.start();
          Directory(savePath).createSync(recursive: true);
        });

        tearDown(() => server.close());

        test('the receiver offers a data port of its own', () async {
          expect(
            DataPlane.instance.available,
            isTrue,
            reason: 'the library is present but did not load',
          );

          final httpClient = HttpClient(
            context: SecurityContext(withTrustedRoots: false),
          )..badCertificateCallback = (_, _, _) => true;
          final socket = IOWebSocketChannel(
            await WebSocket.connect(
              'wss://127.0.0.1:$kTcpPort/ws',
              customClient: httpClient,
            ),
          );
          final frames = socket.stream
              .map((raw) => ControlMessage.fromJson(raw as String))
              .asBroadcastStream();

          final keys = DeviceKeys.generate();
          socket.sink.add(
            RequestFrame(
              sessionId: 'native-negotiate',
              senderName: 'Test Sender',
              files: const [OfferedFile(name: 'a.bin', size: 4)],
              totalSize: 4,
              dataPlaneVersion: kDataPlaneVersion,
              senderCertificate: keys.certificatePem,
              signature: keys.sign(
                attestationStatement(
                  'native-negotiate',
                  deviceIdentity.fingerprint,
                ),
              ),
            ).toJson(),
          );

          final answer = frames.firstWhere((f) => f is AcceptedFrame);
          await server.transferState.firstWhere((s) => s is TransferWaiting);
          server.acceptRequest();

          final accepted = await answer as AcceptedFrame;
          expect(
            accepted.dataPort,
            isNotNull,
            reason: 'the receiver did not advertise its native data plane',
          );
          // A port of its own, clear of the control socket.
          expect(accepted.dataPort, isNot(kTcpPort));
          expect(accepted.dataPort, greaterThan(0));
          httpClient.close(force: true);
        });

        test('the whole loop moves a file through the native path', () async {
          final source = sourceFile('native.bin', 3 * 1024 * 1024 + 5);
          final sent = source.readAsBytesSync();

          final accepted = server.transferState
              .firstWhere((s) => s is TransferWaiting)
              .then((_) => server.acceptRequest());

          client.startUpload(
            [FileResource(source.path)],
            peer(),
            (_, _, _) async => true,
          );
          await accepted;

          final ending = await client.transferState.firstWhere(
            (s) => s.isTerminal,
          );
          expect(
            ending,
            isA<TransferCompleted>(),
            reason: 'the native path did not see the transfer through',
          );
          expect(
            File(path.join(savePath, 'native.bin')).readAsBytesSync(),
            sent,
          );
        });

        test('several files all arrive through the native path', () async {
          final first = sourceFile('native-first.bin', 512 * 1024);
          final second = sourceFile('native-second.bin', 256 * 1024);

          final accepted = server.transferState
              .firstWhere((s) => s is TransferWaiting)
              .then((_) => server.acceptRequest());

          client.startUpload(
            [FileResource(first.path), FileResource(second.path)],
            peer(),
            (_, _, _) async => true,
          );
          await accepted;

          final ending = await client.transferState.firstWhere(
            (s) => s.isTerminal,
          );
          expect(ending, isA<TransferCompleted>());
          expect(
            File(path.join(savePath, 'native-first.bin')).readAsBytesSync(),
            first.readAsBytesSync(),
          );
          expect(
            File(path.join(savePath, 'native-second.bin')).readAsBytesSync(),
            second.readAsBytesSync(),
          );
        });
      },
      skip: debugDataPlaneLibrary(Directory.current.path) == null
          ? 'no data plane library built; run `cargo build --release` in rust/'
          : null,
    );
  });
}
