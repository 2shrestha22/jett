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
/// This is the decision that matters. Under an attack the device answering is
/// the attacker, so a confirmation on the real receiver's screen would never
/// be reached — the sending side is the only one that can refuse in time.
///
/// [peerName] is what that device broadcast, so the person knows which screen
/// to look at. It is unauthenticated, and does not need to be: a wrong name
/// still produces words that do not match.
///
/// [dismissed] completes if the exchange ends while the prompt is still up —
/// the receiver declined, or hung up — and the prompt should close itself
/// rather than keep asking about something already over.
///
/// Returns true to go ahead and remember the key.
typedef TrustPrompt = Future<bool> Function(
  String peerName,
  List<String> words,
  Future<void> dismissed,
);

class Client {
  /// How long to wait for the control socket to come up.
  static const _connectTimeout = Duration(seconds: 10);

  /// How long the receiving device is given to answer before we assume nobody
  /// is going to.
  static const _acceptTimeout = Duration(minutes: 2);

  /// How long to wait, after the last byte has gone, for the receiver to say
  /// what it made of the transfer.
  ///
  /// Only the native path needs this. The Dart path awaits an HTTP response
  /// that the receiver only sends once it has already published its verdict,
  /// so the ordering comes for free there.
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

  /// Whose states are currently being published. Emissions from a superseded
  /// or reset attempt are dropped rather than overwriting a newer one.
  String? _stateSessionId;

  String? _currentFileName;

  /// The native send in flight, if the receiver offered a data port.
  int? _nativeTask;

  /// Why the last send used Dart, when it could have used the native path.
  /// Null means the native path carried it.
  String? _fellBackBecause;

  /// Asks [ipAddr] to accept a transfer and, once accepted, uploads
  /// [resources]. The transfer runs in the background so the caller can show
  /// progress while it happens.
  ///
  /// Returns false without starting anything when a transfer is already
  /// active; the caller should not navigate to the transfer screen in that
  /// case.
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
      // The first connection has nothing to compare against, so its key is
      // recorded and the decision left to the app layer below, where the user
      // can be asked. Once that key is known it is pinned: the upload opens a
      // separate connection on this same client, and without this it would be
      // free to land on a different key than the one that was verified.
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
      // published so reset() can hang up on the receiver, which is what tells
      // it we have gone; waiting for this method to unwind would not, since
      // it spends most of its life parked on the receiver's answer
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

      // Completes with the receiver's answer, or with an error if the socket
      // goes away before one arrives.
      final answer = Completer<ControlMessage>();

      // Fires only when the exchange is genuinely over, so a prompt still on
      // screen can take itself down. Acceptance is not an ending; see
      // _onFrame.
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
          // The receiver hangs up as soon as it has told us how the transfer
          // ended, so a close after a known outcome is just tidying up.
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

      // Asked only after the request has gone, so the receiver is showing its
      // words at the same moment these are on screen. There is nothing to
      // compare against otherwise.
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

      // A receiver that settled below the floor wants a path this build no
      // longer has. Stopping now costs nothing; the alternative is a PUT to an
      // endpoint that build never served, read as a failure much later.
      if ((accepted?.dataPlaneVersion ?? 1) < kDataPlaneVersion) {
        _fail(session, TransferFailure.versionMismatch);
        return;
      }

      _emit(
        session,
        TransferInProgress(sessionId: session, peerAddress: ipAddr),
      );

      // A data port means the receiver has a native data plane listening. Use
      // ours to talk to it, unless this build has none, in which case the Dart
      // handlers on that same device still answer on the control port.
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
      TransferDiagnostics.instance.recordSent(
        TransferReport(
          transport: _fellBackBecause == null
              ? Transport.native
              : Transport.dart,
          fellBackBecause: _fellBackBecause,
          bytes: totalSize,
          elapsed: started.elapsed,
        ),
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
        // Deliberately not an ending. The words still have to be confirmed
        // here, and taking that prompt away would answer it for the user —
        // which, since a dismissed prompt reads as a refusal, would cancel
        // roughly every transfer where the receiver tapped first.
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
        // The receiver confirming it has everything is the authoritative
        // success signal, and it arrives before the upload response does.
        _emit(session, TransferCompleted(sessionId: session));
      case ProgressFrame() || RequestFrame():
        break;
    }
  }

  /// Hands the files to the native data plane and waits for it to finish.
  ///
  /// Returns when every file has gone or something has stopped the transfer.
  /// Nothing is read into this isolate on the way: the only things crossing the
  /// boundary are the paths going out and progress coming back.
  Future<void> _sendNatively(
    String session,
    List<_SizedResource> resources,
    int totalFileSize,
    String ipAddr,
    int dataPort,
    String peerFingerprint,
  ) async {
    // Each resource says for itself how the native side can take it: a path it
    // can open, or a descriptor already opened for it. Only a resource that can
    // offer neither sends through Dart.
    final sources = <({NativeSource source, int size})>[];

    // Ownership of every descriptor in `sources` is this method's until
    // `startSend` accepts them, and nothing else's if it never does. One flag
    // and one `finally` covers every way out — a throw part way through
    // opening them, an early return, the native side refusing.
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
          // Only this device's own send. A file arriving at the same time puts
          // its progress on the same stream.
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
                // Settle at the full size: the last progress event may have been
                // throttled away, and the total must not end short.
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
          // The native side would not take it; the receiver still answers the
          // Dart handlers on its control port.
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
        // Past this point the descriptors are the data plane's, and closing one
        // here would pull it out from under a transfer that is reading it.
        adopted = true;
        _nativeTask = task;
        await finished.future;
        await _awaitReceiverVerdict(session);
      } finally {
        _nativeTask = null;
        await events.cancel();
        _speedometer.stop();
      }

      // The receiver's CompletedFrame is the authoritative success signal and
      // arrives on the control socket, so there is nothing to publish here.
    } finally {
      if (!adopted) _releaseDescriptors(sources);
    }
  }

  /// Closes descriptors opened for a send that is not going to happen.
  ///
  /// Only for the window between opening them and [DataPlane.startSend]
  /// adopting them. Once that call has taken them this must not run, or a
  /// descriptor the transfer is reading from is closed under it.
  void _releaseDescriptors(List<({NativeSource source, int size})> sources) {
    for (final (source: source, size: _) in sources) {
      if (source is NativeFd) DataPlane.instance.closeDescriptor(source.fd);
    }
  }

  /// Waits for the receiver to say whether it has everything.
  ///
  /// The native send finishing only means the bytes left this device. The
  /// receiver confirming is the authoritative signal and arrives on the control
  /// socket, so returning before it lands would unwind the socket and lose it —
  /// leaving a transfer that succeeded looking like it never ended.
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
  /// Pinning has already happened on the control socket; this only carries
  /// bytes to the same address, and the receiver refuses anything whose
  /// session it did not accept.
  HttpClient _fallbackClient() =>
      HttpClient(context: SecurityContext(withTrustedRoots: false))
        ..badCertificateCallback = (_, _, _) => true;

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
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

    // Sent on the client whose callback now pins the peer's key, so these
    // connections cannot land anywhere but the device that was verified.
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
  /// Nothing wraps the bytes, so neither end scans them. Which file each
  /// request carries is in its path, matching the order of the offer the
  /// receiver already approved.
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
      // Drained before the next file so the connection can be reused; an
      // unread body would leave it unusable and force a fresh handshake.
      await response.stream.drain<void>();

      status = response.statusCode;
      if (status != 200) return status;
    }

    return status;
  }

  /// Counts bytes as they go past on their way into a request body.
  ///
  /// The chunks are handed straight on, so measuring costs no copy.
  Stream<List<int>> _counted(Stream<List<int>> source) => source.map((chunk) {
    _speedometer.count(chunk.length);
    return chunk;
  });

  /// True once [session] has reached an outcome, after which the socket and
  /// upload unwinding are just noise.
  bool _isSettled(String session) {
    final current = _transferStateSubject.value;
    return current.sessionId == session && current.isTerminal;
  }

  void _emit(String session, TransferState state) {
    if (_stateSessionId != session) return;
    // whatever ended the transfer first is the truthful reason; later noise
    // from unwinding the socket and the upload must not overwrite it
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

    // Hang up so the receiver learns we are gone now, rather than when our
    // own timeout eventually expires. Closing is the part that matters; the
    // frame is a courtesy for a peer still reading.
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
