import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/identity/device_identity.dart';
import 'package:jett/identity/trust_store.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:jett/crypto/verification.dart';
import 'package:jett/model/device.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/data_plane.dart';
import 'package:jett/transfer/diagnostics.dart';
import 'package:jett/transfer/protocol.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final client = Client();

/// A resource paired with the size it reported when the transfer was offered.
typedef _SizedResource = (Resource resource, int length);

/// Asks the user to confirm a peer's key before anything is sent to it.
///
/// [peerName] is the name that device broadcast, so the person knows which
/// screen to look at. [dismissed] completes if the exchange ends while the
/// prompt is still up. Returns true to go ahead and remember the key.
typedef TrustPrompt = Future<bool> Function(
  String peerName,
  List<String> words,
  Future<void> dismissed,
);

class Client {
  /// How long to wait for the control socket to come up.
  static const _connectTimeout = Duration(seconds: 10);

  /// How long the receiving device is given to answer.
  static const _acceptTimeout = Duration(minutes: 2);

  /// How long to wait, after the last byte has gone, for the receiver's
  /// verdict. Only the native path needs it; the Dart path awaits an HTTP
  /// response that already carries the same ordering.
  static const _verdictTimeout = Duration(seconds: 30);

  final _speedometer = Speedometer();

  ValueStream<SpeedometerReading?> get speedometerReadingsStream =>
      _speedometer.readingStream;

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    const TransferIdle(),
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  Completer<void>? _abortTrigger;

  /// The live control socket, while there is one.
  WebSocketChannel? _socket;

  int _sessionCounter = 0;

  /// Whose states are currently published. Emissions from a superseded or
  /// reset attempt are dropped.
  String? _stateSessionId;

  String? _currentFileName;

  /// The native send in flight, if the receiver offered a data port.
  int? _nativeTask;

  /// Why the last send used Dart, when it could have used the native path.
  /// Null means the native path carried it.
  String? _fellBackBecause;

  /// Asks [ipAddr] to accept a transfer and, once accepted, uploads
  /// [resources] in the background.
  ///
  /// Returns false without starting anything when a transfer is already
  /// active.
  bool startUpload(
    List<Resource> resources,
    Device device,
    TrustPrompt onVerify,
  ) {
    if (_transferStateSubject.value is! TransferIdle) return false;

    final session =
        '${DateTime.now().microsecondsSinceEpoch}-${++_sessionCounter}';
    _stateSessionId = session;
    _abortTrigger = Completer<void>();
    _currentFileName = null;
    _fellBackBecause = null;

    _transferStateSubject.add(
      TransferWaiting(sessionId: session, peerAddress: device.ipAddress),
    );
    unawaited(_run(session, resources, device, onVerify));
    return true;
  }

  Future<void> _run(
    String session,
    List<Resource> resources,
    Device device,
    TrustPrompt onVerify,
  ) async {
    final ipAddr = device.ipAddress;
    WebSocketChannel? socket;
    StreamSubscription<dynamic>? frames;
    HttpClient? httpClient;

    try {
      // The first connection's key is recorded and the decision left to the
      // app layer. Once known it is pinned, so the separate upload connection
      // cannot land on a different key than the one that was verified.
      String? presented;
      String? pinned;
      httpClient = HttpClient(context: SecurityContext(withTrustedRoots: false))
        ..badCertificateCallback = (certificate, host, port) {
          final fingerprint = keyFingerprintOfDer(certificate.der);
          if (fingerprint == null) return false;
          if (pinned != null) return fingerprint == pinned;
          presented = fingerprint;
          return true;
        };

      final rawSocket = await WebSocket.connect(
        'wss://$ipAddr:$kTcpPort/ws',
        customClient: httpClient,
      ).timeout(_connectTimeout);

      final peerFingerprint = presented;
      if (peerFingerprint == null) {
        throw const SocketException('Peer presented no certificate');
      }

      pinned = peerFingerprint;
      final trusted = trustStore.isTrusted(peerFingerprint);

      socket = IOWebSocketChannel(rawSocket);
      // published so reset() can hang up on the receiver; this method spends
      // most of its life parked on the answer
      _socket = socket;

      final sized = <_SizedResource>[];
      var totalSize = 0;
      for (final resource in resources) {
        final length = await resource.length();
        if (length == null) {
          throw FileSystemException('Cannot read file', resource.identifier);
        }
        sized.add((resource, length));
        totalSize += length;
      }

      // Completes with the receiver's answer, or errors if the socket goes
      // away first.
      final answer = Completer<ControlMessage>();

      // Fires only when the exchange is genuinely over. Acceptance is not an
      // ending; see _onFrame.
      final ended = Completer<void>();
      void endExchange() {
        if (!ended.isCompleted) ended.complete();
      }

      frames = socket.stream.listen(
        (raw) => _onFrame(session, raw, answer, endExchange),
        onDone: () {
          endExchange();
          if (!answer.isCompleted) {
            answer.completeError(
              const SocketException('Control socket closed'),
            );
            return;
          }
          // The receiver hangs up once it has reported the outcome.
          if (_isSettled(session)) return;
          // Otherwise it dropped while the files were still moving.
          _fail(session, TransferFailure.peerUnreachable);
          _abort();
        },
        onError: (Object e) {
          endExchange();
          if (!answer.isCompleted) answer.completeError(e);
          _abort();
        },
      );

      socket.sink.add(
        RequestFrame(
          sessionId: session,
          senderName: deviceIdentity.alias,
          files: [
            for (final (resource, length) in sized)
              OfferedFile(
                name: resource.name,
                size: length,
                mimeType: resource.mimeType,
              ),
          ],
          totalSize: totalSize,
          requestVerification: !trusted,
          dataPlaneVersion: kDataPlaneVersion,
          senderCertificate: deviceIdentity.certificatePem,
          signature: deviceIdentity.keys.sign(
            attestationStatement(session, peerFingerprint),
          ),
        ).toJson(),
      );

      // Asked only after the request has gone, so both screens show their
      // words at the same moment.
      if (!trusted) {
        final words = await verificationWordsOffIsolate(
          deviceIdentity.fingerprint,
          peerFingerprint,
        );
        final confirmed = await onVerify(device.name, words, ended.future);
        if (!confirmed) {
          socket.sink.add(CancelFrame(sessionId: session).toJson());
          _emit(
            session,
            TransferCancelled(sessionId: session, by: CancelledBy.sender),
          );
          return;
        }
        await trustStore.trust(peerFingerprint, device.name);
      }

      final reply = await answer.future.timeout(_acceptTimeout);
      if (reply is DeclinedFrame) {
        _fail(session, reply.reason);
        return;
      }

      // Anything that is not an acceptance has already returned above.
      final accepted = reply is AcceptedFrame ? reply : null;

      // A receiver below the floor wants a path this build no longer serves.
      if ((accepted?.dataPlaneVersion ?? 1) < kDataPlaneVersion) {
        _fail(session, TransferFailure.versionMismatch);
        return;
      }

      _emit(
        session,
        TransferInProgress(sessionId: session, peerAddress: ipAddr),
      );

      // A data port means the receiver has a native data plane listening.
      // Without one on either side, its Dart handlers still answer.
      final dataPort = accepted?.dataPort;
      final started = Stopwatch()..start();
      if (dataPort != null && DataPlane.instance.available) {
        await _sendNatively(
          session,
          sized,
          totalSize,
          ipAddr,
          dataPort,
          peerFingerprint,
        );
      } else {
        _fellBackBecause = dataPort == null
            ? 'the receiver offered no native data plane'
            : 'this device has no native data plane';
        await _upload(session, sized, totalSize, ipAddr, httpClient);
      }
      started.stop();
      TransferDiagnostics.instance.sent.value = TransferReport(
        transport: _fellBackBecause == null ? Transport.native : Transport.dart,
        fellBackBecause: _fellBackBecause,
        bytes: totalSize,
        elapsed: started.elapsed,
      );
    } on TimeoutException {
      _fail(session, TransferFailure.timeout);
    } on WebSocketChannelException catch (e) {
      log('Could not open a control socket to $ipAddr', error: e);
      _fail(session, TransferFailure.peerUnreachable);
    } on SocketException catch (e) {
      log('Could not reach $ipAddr', error: e);
      _fail(session, TransferFailure.peerUnreachable);
    } on FileSystemException catch (e) {
      log('Could not read a file to send', error: e);
      _fail(session, TransferFailure.fileUnreadable);
    } catch (e, s) {
      log('Transfer failed', error: e, stackTrace: s);
      _fail(session, TransferFailure.unknown);
    } finally {
      await frames?.cancel();
      if (identical(_socket, socket)) _socket = null;
      await socket?.sink.close();
      httpClient?.close(force: true);
      _speedometer.stop();
    }
  }

  void _onFrame(
    String session,
    Object? raw,
    Completer<ControlMessage> answer,
    void Function() onExchangeEnded,
  ) {
    final ControlMessage frame;
    try {
      frame = ControlMessage.fromJson(raw! as String);
    } catch (e) {
      log('Unreadable control frame', error: e);
      return;
    }
    if (frame.sessionId != session) return;

    switch (frame) {
      case AcceptedFrame():
        // Deliberately not an ending: the words still have to be confirmed
        // here, and a dismissed prompt reads as a refusal.
        if (!answer.isCompleted) answer.complete(frame);
      case DeclinedFrame():
        if (!answer.isCompleted) answer.complete(frame);
        onExchangeEnded();
      case FailedFrame(:final reason):
        _fail(session, reason);
        onExchangeEnded();
        _abort();
      case CancelFrame():
        _emit(
          session,
          TransferCancelled(sessionId: session, by: CancelledBy.receiver),
        );
        onExchangeEnded();
        _abort();
      case CompletedFrame():
        // The authoritative success signal, and it arrives before the upload
        // response does.
        _emit(session, TransferCompleted(sessionId: session));
      case ProgressFrame() || RequestFrame():
        break;
    }
  }

  /// Hands the files to the native data plane and waits for it to finish.
  ///
  /// Nothing is read into this isolate: only paths go out and progress comes
  /// back.
  Future<void> _sendNatively(
    String session,
    List<_SizedResource> resources,
    int totalFileSize,
    String ipAddr,
    int dataPort,
    String peerFingerprint,
  ) async {
    // Each resource offers a path or an open descriptor. One that can offer
    // neither sends through Dart.
    final sources = <({NativeSource source, int size})>[];

    // The descriptors in `sources` are this method's until `startSend`
    // accepts them; one flag and one `finally` covers every way out.
    var adopted = false;
    try {
      for (final (resource, length) in resources) {
        final source = await resource.nativeSource();
        if (source == null) {
          _fellBackBecause =
              '${resource.name} has no path the native side can '
              'open, and no descriptor for it';
          log(
            '${resource.name} cannot be opened natively; sending it from Dart',
          );
          return await _upload(
            session,
            resources,
            totalFileSize,
            ipAddr,
            _fallbackClient(),
          );
        }
        sources.add((source: source, size: length));
      }

      _speedometer.reset();
      _speedometer.fileSize = totalFileSize;

      final finished = Completer<void>();
      var counted = 0;
      var finishedFiles = 0;
      final perFile = <int, int>{};
      int? currentIndex;

      final events = DataPlane.instance.events
          // Only this device's own send; an incoming file shares the stream.
          .where((event) => event.sending && event.session == session)
          .listen((event) {
            switch (event) {
              case DataPlaneProgress(:final index, :final transferred):
                perFile[index] = transferred;
                final total = perFile.values.fold(0, (a, b) => a + b);
                if (total > counted) {
                  _speedometer.count(total - counted);
                  counted = total;
                }
                if (currentIndex != index && index < resources.length) {
                  currentIndex = index;
                  _currentFileName = resources[index].$1.name;
                  _emit(
                    session,
                    TransferInProgress(
                      sessionId: session,
                      peerAddress: ipAddr,
                      fileName: _currentFileName,
                    ),
                  );
                }

              case DataPlaneFileFinished(:final index):
                // Settle at the full size; the last progress event may have
                // been throttled away.
                if (index < resources.length) {
                  perFile[index] = resources[index].$2;
                  final total = perFile.values.fold(0, (a, b) => a + b);
                  if (total > counted) {
                    _speedometer.count(total - counted);
                    counted = total;
                  }
                }
                finishedFiles++;
                if (finishedFiles >= resources.length &&
                    !finished.isCompleted) {
                  finished.complete();
                }

              case DataPlaneFailed(:final message):
                log('Native send failed: $message');
                _fail(session, TransferFailure.unknown);
                if (!finished.isCompleted) finished.complete();

              case DataPlaneCancelled():
                _emit(
                  session,
                  TransferCancelled(sessionId: session, by: CancelledBy.sender),
                );
                if (!finished.isCompleted) finished.complete();
            }
          });

      try {
        final task = DataPlane.instance.startSend(
          host: ipAddr,
          port: dataPort,
          token: session,
          peerFingerprint: peerFingerprint,
          files: sources,
        );
        if (task == null) {
          // The receiver still answers the Dart handlers on its control port.
          _fellBackBecause = 'the native data plane refused the send';
          await _upload(
            session,
            resources,
            totalFileSize,
            ipAddr,
            _fallbackClient(),
          );
          return;
        }
        // Past this point the descriptors belong to the data plane.
        adopted = true;
        _nativeTask = task;
        await finished.future;
        await _awaitReceiverVerdict(session);
      } finally {
        _nativeTask = null;
        await events.cancel();
        _speedometer.stop();
      }

      // The receiver's CompletedFrame is the success signal, so there is
      // nothing to publish here.
    } finally {
      if (!adopted) _releaseDescriptors(sources);
    }
  }

  /// Closes descriptors opened for a send that is not going to happen.
  ///
  /// Only valid before [DataPlane.startSend] adopts them; after that it would
  /// close a descriptor the transfer is reading from.
  void _releaseDescriptors(List<({NativeSource source, int size})> sources) {
    for (final (source: source, size: _) in sources) {
      if (source is NativeFd) DataPlane.instance.closeDescriptor(source.fd);
    }
  }

  /// Waits for the receiver to say whether it has everything.
  ///
  /// The native send finishing only means the bytes left this device; returning
  /// before the receiver's frame lands would unwind the socket and lose it.
  Future<void> _awaitReceiverVerdict(String session) async {
    if (_isSettled(session)) return;
    try {
      await _transferStateSubject
          .firstWhere((state) => state.sessionId == session && state.isTerminal)
          .timeout(_verdictTimeout);
    } on TimeoutException {
      _fail(session, TransferFailure.timeout);
    }
  }

  /// A client for the rare fall back out of the native path mid-flight.
  ///
  /// Pinning already happened on the control socket, and the receiver refuses
  /// any session it did not accept.
  HttpClient _fallbackClient() =>
      HttpClient(context: SecurityContext(withTrustedRoots: false))
        ..badCertificateCallback = (_, _, _) => true;

  /// Uploads files to [ipAddr]. Only valid once the request is accepted.
  Future<void> _upload(
    String session,
    List<_SizedResource> resources,
    int totalFileSize,
    String ipAddr,
    HttpClient httpClient,
  ) async {
    // user already cancelled send, using reset()
    if (_abortTrigger == null) return;

    _speedometer.reset();
    _speedometer.fileSize = totalFileSize;

    // The client's callback pins the peer's key, so these connections cannot
    // land anywhere but the verified device.
    final sender = IOClient(httpClient);
    final status = await _uploadBlobs(session, resources, ipAddr, sender);

    if (status == 200) {
      _emit(session, TransferCompleted(sessionId: session));
    } else {
      _fail(session, _failureForStatus(status));
    }
  }

  /// Sends each file as its own request, with the file as the body.
  ///
  /// The file's index is in the request path, matching the order of the offer
  /// the receiver approved.
  ///
  /// Returns the status of the first request that was not accepted, or of the
  /// last one when every file went through.
  Future<int> _uploadBlobs(
    String session,
    List<_SizedResource> resources,
    String ipAddr,
    IOClient sender,
  ) async {
    var status = 200;

    for (var index = 0; index < resources.length; index++) {
      final trigger = _abortTrigger;
      // reset() clears this; there is no point starting another file.
      if (trigger == null) return status;

      final (resource, contentLength) = resources[index];
      _currentFileName = resource.name;
      _emit(
        session,
        TransferInProgress(
          sessionId: session,
          peerAddress: ipAddr,
          fileName: resource.name,
        ),
      );

      final request = http.AbortableStreamedRequest(
        'PUT',
        Uri.parse('https://$ipAddr:$kTcpPort/v2/blob/$session/$index'),
        abortTrigger: trigger.future,
      )..contentLength = contentLength;

      unawaited(
        request.sink
            .addStream(_counted(resource.openRead().cast<List<int>>()))
            .catchError((Object e, StackTrace s) {
              log('Request body stream failed', error: e, stackTrace: s);
              // unblock send(), which would otherwise wait on a body that will
              // never arrive
              _abort();
            })
            .whenComplete(request.sink.close),
      );

      final response = await sender.send(request);
      // Drained so the connection can be reused; an unread body would force a
      // fresh handshake.
      await response.stream.drain<void>();

      status = response.statusCode;
      if (status != 200) return status;
    }

    return status;
  }

  /// Counts bytes as they go past on their way into a request body.
  Stream<List<int>> _counted(Stream<List<int>> source) => source.map((chunk) {
    _speedometer.count(chunk.length);
    return chunk;
  });

  /// True once [session] has reached an outcome.
  bool _isSettled(String session) {
    final current = _transferStateSubject.value;
    return current.sessionId == session && current.isTerminal;
  }

  void _emit(String session, TransferState state) {
    if (_stateSessionId != session) return;
    // the first ending is the truthful reason; later unwinding noise must not
    // overwrite it
    if (_isSettled(session)) return;
    _transferStateSubject.add(state);
  }

  void _fail(String session, TransferFailure reason) =>
      _emit(session, TransferFailed(sessionId: session, reason: reason));

  void _abort() {
    final trigger = _abortTrigger;
    if (trigger != null && !trigger.isCompleted) trigger.complete();
  }

  /// Aborts any in-flight transfer and returns to [TransferIdle] so a new
  /// transfer can be started.
  void reset() {
    final session = _stateSessionId;
    final socket = _socket;
    _socket = null;

    // Hang up so the receiver learns we are gone now rather than at its own
    // timeout. Closing is what matters; the frame is a courtesy.
    if (socket != null) {
      if (session != null) {
        try {
          socket.sink.add(CancelFrame(sessionId: session).toJson());
        } catch (e) {
          log('Could not announce cancellation', error: e);
        }
      }
      unawaited(socket.sink.close().catchError((Object _) {}));
    }

    // invalidate the running attempt so its result cannot land after this
    _stateSessionId = null;
    final native = _nativeTask;
    if (native != null) {
      DataPlane.instance.cancelSend(native);
      _nativeTask = null;
    }
    _abort();
    _abortTrigger = null;
    _currentFileName = null;
    _speedometer.reset();
    _transferStateSubject.add(const TransferIdle());
  }
}

TransferFailure _failureForStatus(int statusCode) => switch (statusCode) {
  403 => TransferFailure.declined,
  409 => TransferFailure.busy,
  408 => TransferFailure.timeout,
  _ => TransferFailure.unknown,
};
