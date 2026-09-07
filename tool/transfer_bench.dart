// Where Jett's transfer time actually goes.
//
// Compares the current multipart path against the same transport without
// multipart, and against the same transport with writes buffered the way the
// Rust data plane buffers them. Every configuration moves the same bytes over
// the same TLS, through the same HTTP client and server, onto a real disk, so
// the differences are attributable.
//
// Run:  mise exec -- dart compile exe tool/transfer_bench.dart -o /tmp/jbench && /tmp/jbench
//
// Compiled rather than `dart run`, because a JIT number would understate Dart
// against a release-mode Rust binary and the point is a fair comparison.
//
// The server runs in its own isolate, so it gets its own thread. Sharing one
// event loop between both ends would have them compete for a single core and
// report roughly half of what two devices would actually see — the Rust
// comparison uses a multi-threaded runtime, and an unfair baseline would
// overstate the case for porting.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:jett/transfer/speedometer.dart';

const payloadBytes = 512 * 1024 * 1024;

/// Matches the Rust side's `WRITE_BUFFER_BYTES`, so configuration C is a
/// like-for-like comparison rather than a different idea.
const writeBufferBytes = 1024 * 1024;

late final String _certificatePem;
late final String _privateKeyPem;
late final File payload;
late final Directory workspace;

Future<void> main() async {
  workspace = Directory.systemTemp.createTempSync('jett-bench');
  _loadIdentity();
  payload = await _makePayload();

  stdout.writeln('\n  ${payloadBytes ~/ (1024 * 1024)} MiB over TLS + HTTP to disk, loopback\n');

  await _report(
    'A  multipart + openWrite   (Jett today)',
    () => _run(Receive.multipart, multipartBody: true),
  );
  await _report(
    'B  raw PUT  + openWrite',
    () => _run(Receive.raw, multipartBody: false),
  );
  await _report(
    'C  raw PUT  + 1 MiB buffer',
    () => _run(Receive.rawBuffered, multipartBody: false),
  );
  await _report(
    'E  raw PUT, as server.dart does it',
    () => _run(Receive.rawAsServerDoesIt, multipartBody: false),
  );
  // How much of the gap is the record layer rather than Dart itself. Jett will
  // always run encrypted, so this is a diagnostic, not an option.
  await _report(
    'D  raw PUT, no TLS         (diagnostic)',
    () => _run(Receive.raw, multipartBody: false, tls: false),
  );

  stdout.writeln('\n  Rust data plane, same shape: 230 MB/s (see rust/tests/throughput.rs)\n');
  workspace.deleteSync(recursive: true);
}

// ---------------------------------------------------------------------------
// Receiving side — runs in its own isolate.
// ---------------------------------------------------------------------------

/// How the receiver handles the body. Sent to the isolate as a plain value
/// because a closure cannot cross an isolate boundary.
enum Receive {
  multipart,
  raw,
  rawBuffered,

  /// Raw body plus the per-chunk bookkeeping the real server does: counting
  /// into the speedometer and checking the clock to decide whether a progress
  /// frame is due. Both paths in `server.dart` do this on every chunk, so it
  /// is shared cost that neither the multipart nor the raw figure above
  /// includes.
  rawAsServerDoesIt,
}

class _ServerSpec {
  final SendPort reply;
  final bool tls;
  final Receive mode;
  final String destination;
  final String certificatePem;
  final String privateKeyPem;

  const _ServerSpec(
    this.reply,
    this.tls,
    this.mode,
    this.destination,
    this.certificatePem,
    this.privateKeyPem,
  );
}

Future<void> _serverMain(_ServerSpec spec) async {
  final destination = File(spec.destination);

  Future<Response> handler(Request request) async {
    switch (spec.mode) {
      // Configuration A — what Jett does now.
      case Receive.multipart:
        final form = request.formData();
        if (form == null) return Response(400);
        await for (final data in form.formData) {
          final sink = destination.openWrite();
          await for (final chunk in data.part) {
            sink.add(chunk);
          }
          await sink.flush();
          await sink.close();
        }
        return Response.ok('');

      // Configuration B — body is the file, one write per network chunk.
      case Receive.raw:
        final sink = destination.openWrite();
        await for (final chunk in request.read()) {
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        return Response.ok('');

      // Configuration E — B plus what server.dart actually does per chunk.
      case Receive.rawAsServerDoesIt:
        final sink = destination.openWrite();
        final speedometer = Speedometer()..fileSize = payloadBytes;
        var lastProgress = DateTime.now();
        var received = 0;
        // server.dart wraps the body in a stall timeout, which re-arms a timer
        // on every chunk. Included here because it is per-chunk work that only
        // the real handler does.
        await for (final chunk
            in request.read().timeout(const Duration(seconds: 10))) {
          received += chunk.length;
          if (received > payloadBytes) return Response(400);
          sink.add(chunk);
          speedometer.count(chunk.length);
          final now = DateTime.now();
          if (now.difference(lastProgress) >=
              const Duration(milliseconds: 300)) {
            lastProgress = now;
            // The real server serialises a ProgressFrame here and pushes it
            // down the control socket; reading the total is the part that
            // happens per chunk regardless.
            speedometer.readingStream.value?.totalBytesTransferred;
          }
        }
        await sink.flush();
        await sink.close();
        speedometer.stop();
        return Response.ok('');

      // Configuration C — as B, with writes coalesced the way the Rust side
      // coalesces them, to separate multipart cost from syscall cost.
      case Receive.rawBuffered:
        final sink = destination.openWrite();
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in request.read()) {
          buffer.add(chunk);
          if (buffer.length >= writeBufferBytes) sink.add(buffer.takeBytes());
        }
        if (buffer.isNotEmpty) sink.add(buffer.takeBytes());
        await sink.flush();
        await sink.close();
        return Response.ok('');
    }
  }

  final server = await shelf_io.serve(
    handler,
    InternetAddress.loopbackIPv4,
    0,
    securityContext: spec.tls
        ? (SecurityContext(withTrustedRoots: false)
            ..useCertificateChainBytes(utf8.encode(spec.certificatePem))
            ..usePrivateKeyBytes(utf8.encode(spec.privateKeyPem)))
        : null,
  );
  spec.reply.send(server.port);
  // Stays alive serving until the parent kills the isolate.
}

// ---------------------------------------------------------------------------
// Sending side — the main isolate.
// ---------------------------------------------------------------------------

Future<Duration> _run(
  Receive mode, {
  required bool multipartBody,
  bool tls = true,
}) async {
  final destination = File('${workspace.path}/received-${mode.name}-$tls.bin');
  final ready = ReceivePort();
  final isolate = await Isolate.spawn(
    _serverMain,
    _ServerSpec(
      ready.sendPort,
      tls,
      mode,
      destination.path,
      _certificatePem,
      _privateKeyPem,
    ),
  );
  final port = await ready.first as int;
  ready.close();

  final client = _client();
  final scheme = tls ? 'https' : 'http';
  final uri = Uri.parse(
    multipartBody
        ? '$scheme://127.0.0.1:$port/upload'
        : '$scheme://127.0.0.1:$port/v2/blob/token/0',
  );

  final watch = Stopwatch()..start();

  final http.StreamedRequest request;
  if (multipartBody) {
    final multipart = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile(
          'files',
          payload.openRead().cast<List<int>>(),
          payloadBytes,
          filename: 'payload.bin',
        ),
      );
    // finalize() before reading the content type: the boundary is only chosen
    // there, so the header does not exist until the body stream does. Jett's
    // client.dart orders it the same way.
    final body = multipart.finalize();
    request = http.StreamedRequest('POST', uri)
      ..headers[HttpHeaders.contentTypeHeader] =
          multipart.headers[HttpHeaders.contentTypeHeader]!;
    unawaited(request.sink.addStream(body).whenComplete(request.sink.close));
  } else {
    request = http.StreamedRequest('PUT', uri)..contentLength = payloadBytes;
    unawaited(
      request.sink
          .addStream(payload.openRead().cast<List<int>>())
          .whenComplete(request.sink.close),
    );
  }

  final response = await client.send(request);
  await response.stream.drain<void>();
  watch.stop();

  client.close();
  isolate.kill(priority: Isolate.immediate);

  final written = destination.lengthSync();
  if (written != payloadBytes) {
    throw StateError('${mode.name}: wrote $written bytes, expected $payloadBytes');
  }
  destination.deleteSync();
  return watch.elapsed;
}

/// Pinning is not what is being measured, so the certificate is simply
/// accepted. The handshake and the record layer — the costly parts — happen
/// either way.
IOClient _client() => IOClient(
  HttpClient(context: SecurityContext(withTrustedRoots: false))
    ..badCertificateCallback = (_, _, _) => true,
);

Future<void> _report(String label, Future<Duration> Function() run) async {
  final elapsed = await run();
  final megabytes = payloadBytes / (1024 * 1024);
  final rate = megabytes / (elapsed.inMilliseconds / 1000);
  stdout.writeln(
    '  ${label.padRight(38)} ${rate.toStringAsFixed(0).padLeft(4)} MB/s'
    '   [${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s]',
  );
}

/// The identity minted by Jett's own `DeviceKeys.generate()` — the same fixture
/// the Rust interop test uses, so both benchmarks handshake with the same key.
void _loadIdentity() {
  const fixtures = 'rust/tests/fixtures';
  _certificatePem = File('$fixtures/dart_identity.pem').readAsStringSync();
  _privateKeyPem = File('$fixtures/dart_identity.key').readAsStringSync();
}

Future<File> _makePayload() async {
  final file = File('${workspace.path}/payload.bin');
  final sink = file.openWrite();
  // Varied rather than a run of zeroes: a constant buffer can flatter a copy
  // path and would hide a bug that writes the right count at the wrong offset.
  final block = Uint8List(1024 * 1024);
  for (var i = 0; i < block.length; i++) {
    block[i] = (i * 31 + 7) & 0xFF;
  }
  for (var written = 0; written < payloadBytes; written += block.length) {
    sink.add(block);
  }
  await sink.flush();
  await sink.close();
  return file;
}
