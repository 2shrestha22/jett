import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/identity/device_identity.dart';
import 'package:jett/identity/trust_store.dart';
import 'package:jett/crypto/device_keys.dart';
import 'package:jett/crypto/verification.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/data_plane.dart';
import 'package:jett/transfer/diagnostics.dart';
import 'package:jett/transfer/protocol.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/save_path.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Whether received bytes are dropped instead of written to disk.
///
/// On in debug builds, where transfers are usually being exercised for their
/// own sake and filling the download directory is a nuisance. Mutable so that
/// tests which care what lands on disk can turn it off — with it left on, the
/// receiving path cannot be checked at all.
bool disableFileWrite = kDebugMode;

final server = Server();

/// One incoming transfer, tied to the control socket that opened it. The
/// socket closing is what tells us the sender is gone.
class _Session {
  final String id;
  final String peerAddress;
  final WebSocketChannel socket;
  final String senderName;
  final List<OfferedFile> files;
  final int totalSize;

  /// The sender's fingerprint, proven by the signature on its request.
  final String senderFingerprint;

  /// The bulk-data path settled on for this transfer: the lower of what the
  /// two builds support. See [kDataPlaneVersion].
  final int dataPlaneVersion;

  /// Where each offered file is being written, resolved on the first request
  /// for that index so a retried one does not allocate a second name.
  final Map<int, File> destinations = {};

  /// How many of the offered files have arrived in full. The transfer is over
  /// when this reaches the number offered.
  int filesReceived = 0;

  /// Bytes the native data plane has reported per file. It reports a total per
  /// file while the speedometer counts increments, so the running sum is kept
  /// here and only the difference is handed on.
  final Map<int, int> nativeBytes = {};
  int nativeCounted = 0;

  /// Which file the native data plane is on, so the UI is only told when that
  /// changes rather than on every progress event.
  int? nativeIndex;

  /// Which path actually carried the bytes, and how long they took. Recorded
  /// so it can be read on the device rather than inferred from a speed.
  Transport? transport;
  final Stopwatch clock = Stopwatch();

  /// Whether the two people still have to compare words for this pair.
  final bool showVerification;

  /// Set once the user has approved; only then may the sender upload.
  bool accepted = false;

  /// Set once bytes start arriving.
  bool uploading = false;

  /// Who gave up, once somebody has. Stops the file loop.
  CancelledBy? cancelledBy;
  bool get cancelled => cancelledBy != null;

  /// Set when the control socket is gone; nothing more can be sent on it.
  bool closed = false;

  _Session({
    required this.id,
    required this.peerAddress,
    required this.socket,
    required this.senderName,
    required this.files,
    required this.totalSize,
    required this.senderFingerprint,
    required this.showVerification,
    required this.dataPlaneVersion,
  });

  void send(ControlMessage frame) {
    if (closed) return;
    try {
      socket.sink.add(frame.toJson());
    } catch (e) {
      log('Could not send ${frame.runtimeType} to $peerAddress', error: e);
    }
  }

  void hangUp() {
    if (closed) return;
    closed = true;
    unawaited(socket.sink.close());
  }
}

class Server {
  /// How long an accepted transfer may sit before any bytes arrive. Guards
  /// against a sender that is accepted and then stops without dropping its
  /// socket.
  static const _uploadStartTimeout = Duration(seconds: 30);

  /// How long a stalled upload is tolerated before the transfer is failed.
  static const _chunkTimeout = Duration(seconds: 10);

  /// Progress is reported to the sender no more often than this.
  static const _progressInterval = Duration(milliseconds: 300);

  final _router = Router();
  HttpServer? _server;

  /// The port the native data plane bound, or null if it is not running. Told
  /// to senders in the acceptance so they can send bytes there instead.
  int? _dataPort;
  StreamSubscription<DataPlaneEvent>? _dataPlaneEvents;

  late String _downloadPath;

  final _speedometer = Speedometer();
  ValueStream<SpeedometerReading?> get speedometerReadingStream =>
      _speedometer.readingStream;

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    const TransferIdle(),
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  _Session? _session;

  /// Whose states are currently being published. Emissions from any other
  /// session are dropped, so a superseded attempt cannot overwrite a newer one.
  String? _stateSessionId;

  String get senderIp => _session?.peerAddress ?? '';
  String get senderName => _session?.senderName ?? '';
  List<OfferedFile> get offeredFiles => _session?.files ?? const [];
  int get offeredTotalSize => _session?.totalSize ?? 0;

  /// Words to show alongside the prompt so the two people can confirm the
  /// sender is really talking to this device. Empty once the sender knows this
  /// device's key.
  ///
  /// Off the main isolate: the derivation is deliberately slow, to make an
  /// attacker's search for a colliding key expensive, and that cost would
  /// otherwise land as a freeze right before the dialog appears.
  Future<List<String>> verificationPrompt() async {
    final session = _session;
    if (session == null || !session.showVerification) return const [];
    return verificationWordsOffIsolate(
      deviceIdentity.fingerprint,
      session.senderFingerprint,
    );
  }

  Future<void> start() async {
    _downloadPath = await getSavePath();

    _router
      ..get('/ws', _handleControlSocket)
      ..put('/v2/blob/<session>/<index>', _handleBlob);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);

    // Served under this device's own certificate. Senders pin it by
    // fingerprint, which is what the verification words let the two people
    // confirm the first time round.
    final security = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(deviceIdentity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(deviceIdentity.privateKeyPem));

    _server = await io.serve(
      handler,
      InternetAddress.anyIPv4,
      kTcpPort,
      securityContext: security,
    );

    // Serves the same certificate, on a port of its own. Returns null when the
    // native library is unavailable, in which case senders are never told about
    // it and everything goes through the Dart handlers above.
    _dataPort = await DataPlane.instance.startServer(
      certificatePem: deviceIdentity.certificatePem,
      privateKeyPem: deviceIdentity.privateKeyPem,
    );
    _dataPlaneEvents ??= DataPlane.instance.events.listen(_onDataPlaneEvent);
  }

  FutureOr<Response> _handleControlSocket(Request request) {
    final peer = _getClientAddress(request);
    // built per request because the peer address is only available here
    final handler = webSocketHandler(
      (WebSocketChannel socket, _) => _onControlSocket(socket, peer),
    );
    return handler(request);
  }

  void _onControlSocket(WebSocketChannel socket, String peer) {
    void socketGone() {
      final session = _session;
      if (session == null || !identical(session.socket, socket)) return;
      session.closed = true;
      session.cancelledBy = CancelledBy.sender;
      // An upload in flight will notice `cancelled` and publish its own
      // ending; otherwise the sender left mid-prompt and we drop to idle,
      // which is what dismisses the dialog.
      if (!session.uploading) _endSession(session, const TransferIdle());
    }

    socket.stream.listen(
      (raw) {
        final ControlMessage frame;
        try {
          frame = ControlMessage.fromJson(raw as String);
        } catch (e) {
          log('Unreadable control frame from $peer', error: e);
          return;
        }

        switch (frame) {
          case RequestFrame():
            _onRequestFrame(frame, socket, peer);
          case CancelFrame():
            final session = _session;
            if (session != null &&
                session.id == frame.sessionId &&
                identical(session.socket, socket)) {
              session.cancelledBy = CancelledBy.sender;
              if (!session.uploading) {
                _endSession(session, const TransferIdle());
              }
            }
          case AcceptedFrame() ||
              DeclinedFrame() ||
              ProgressFrame() ||
              CompletedFrame() ||
              FailedFrame():
            // receiver-to-sender frames; nothing to do with them here
            break;
        }
      },
      onDone: socketGone,
      onError: (Object e) {
        log('Control socket error from $peer', error: e);
        socketGone();
      },
      cancelOnError: true,
    );
  }

  void _onRequestFrame(
    RequestFrame frame,
    WebSocketChannel socket,
    String peer,
  ) {
    void refuse(TransferFailure reason) {
      try {
        socket.sink.add(
          DeclinedFrame(sessionId: frame.sessionId, reason: reason).toJson(),
        );
      } catch (_) {
        // the socket is already gone; nothing to tell them on
      }
      unawaited(socket.sink.close());
    }

    if (frame.protocolVersion != kProtocolVersion) {
      refuse(TransferFailure.versionMismatch);
      return;
    }

    // A sender that cannot do [kDataPlaneVersion] is one this build has no
    // way to carry bytes for. Refusing here, before the user is asked to accept
    // anything, is the difference between a peer that says no and a transfer
    // that dies once it is already moving.
    if (frame.dataPlaneVersion < kDataPlaneVersion) {
      refuse(TransferFailure.versionMismatch);
      return;
    }

    // Dart never shows us a client certificate, so the sender proves which
    // device it is by signing this session and our fingerprint. Without that
    // there is no identity here to trust or to build the words from.
    final senderFingerprint = verifiedSignerFingerprint(
      certificatePem: frame.senderCertificate,
      signature: frame.signature,
      statement: attestationStatement(
        frame.sessionId,
        deviceIdentity.fingerprint,
      ),
    );
    if (senderFingerprint == null) {
      refuse(TransferFailure.unverifiedSender);
      return;
    }

    final current = _session;
    if (current != null && !identical(current.socket, socket)) {
      refuse(TransferFailure.busy);
      return;
    }
    if (current != null && current.uploading) {
      refuse(TransferFailure.busy);
      return;
    }

    final session = _Session(
      id: frame.sessionId,
      dataPlaneVersion: negotiatedDataPlaneVersion(frame.dataPlaneVersion),
      peerAddress: peer,
      socket: socket,
      senderName: frame.senderName,
      files: frame.files,
      totalSize: frame.totalSize,
      senderFingerprint: senderFingerprint,
      // either side not knowing the other is reason enough to compare
      showVerification:
          frame.requestVerification || !trustStore.isTrusted(senderFingerprint),
    );
    _session = session;
    _stateSessionId = session.id;
    _transferStateSubject.add(
      TransferWaiting(sessionId: session.id, peerAddress: peer),
    );
  }

  void acceptRequest() {
    final session = _session;
    if (session == null || session.accepted || session.closed) return;

    session.accepted = true;
    // accepting is also the moment this device vouches for the sender's key,
    // so a later transfer from it does not ask again
    unawaited(trustStore.trust(session.senderFingerprint, session.senderName));
    unawaited(_announceAcceptance(session));

    Timer(_uploadStartTimeout, () {
      if (!identical(_session, session) || session.uploading) return;
      session.send(
        FailedFrame(sessionId: session.id, reason: TransferFailure.timeout),
      );
      session.hangUp();
      _endSession(session, const TransferIdle());
    });
  }

  /// Answers an accepted request, once it is known where the files will land.
  ///
  /// Choosing the destinations here rather than as each file arrives is what
  /// lets the native data plane be told them up front; it writes where it is
  /// told and never sees a filename. The Dart handlers reuse the same paths.
  Future<void> _announceAcceptance(_Session session) async {
    int? dataPort;

    // The floor check when the request arrived already guarantees the version;
    // it is repeated here because this is the line that decides whether a peer
    // is handed a port, and that should not depend on a check made elsewhere.
    if (session.dataPlaneVersion >= kDataPlaneVersion && _dataPort != null) {
      final destinations = <({String destination, int size})>[];
      for (var index = 0; index < session.files.length; index++) {
        final offered = session.files[index];
        final target = await _unusedPathFor(
          safeFileName(offered.name),
          // Names are claimed as they are chosen. Two files offered under one
          // name would otherwise both resolve to it, since neither exists on
          // disk yet, and the second would overwrite the first.
          claimed: session.destinations.values.map((f) => f.path).toSet(),
        );
        session.destinations[index] = target;
        destinations.add((destination: target.path, size: offered.size));
      }

      if (await DataPlane.instance.openSession(
        token: session.id,
        destinations: destinations,
      )) {
        dataPort = _dataPort;
      }
      // A session the native side would not open leaves dataPort null, and the
      // sender falls back to the Dart handlers rather than failing.
    }

    if (session.closed) return;
    session.send(
      AcceptedFrame(
        sessionId: session.id,
        dataPlaneVersion: session.dataPlaneVersion,
        dataPort: dataPort,
      ),
    );
  }

  void rejectRequest() {
    final session = _session;
    if (session == null || session.accepted) return;

    session.send(
      DeclinedFrame(sessionId: session.id, reason: TransferFailure.declined),
    );
    session.hangUp();
    // Declining is not a failure on this side; drop straight back to idle.
    _endSession(session, const TransferIdle());
  }

  /// One file of a v2 transfer. The body is the file.
  ///
  /// Nothing parses the body: it is written as it arrives. Which file this is
  /// comes from the index in the path rather than from a filename inside the
  /// body, so the name written to disk is the one from the offer the user
  /// approved — not one the sender chose separately afterwards.
  Future<Response> _handleBlob(
    Request request,
    String sessionId,
    String rawIndex,
  ) async {
    final session = _session;
    final peer = _getClientAddress(request);

    if (session == null ||
        session.id != sessionId ||
        !session.accepted ||
        session.peerAddress != peer) {
      return Response.forbidden('No accepted transfer for this peer');
    }
    final index = int.tryParse(rawIndex);
    if (index == null || index < 0 || index >= session.files.length) {
      return Response.notFound('No such file in this transfer');
    }

    final offered = session.files[index];
    final fileName = safeFileName(offered.name);

    // Only the first file of the transfer starts the clock; the rest arrive on
    // their own requests and must keep counting against the same total.
    if (!session.uploading) {
      session.uploading = true;
      session.transport = Transport.dart;
      session.clock.start();
      _speedometer.reset();
      _speedometer.fileSize = session.totalSize;
    }
    _emit(
      session,
      TransferInProgress(
        sessionId: session.id,
        peerAddress: peer,
        fileName: fileName,
      ),
    );

    final failure = await _receiveGuarded(session, () async {
      var destination = session.destinations[index];
      if (destination == null) {
        destination = await _unusedPathFor(fileName);
        session.destinations[index] = destination;
      }
      await _receiveBlob(request, session, destination, offered, fileName);
    });
    if (failure != null) {
      _speedometer.stop();
      return failure;
    }

    if (!session.cancelled) {
      session.filesReceived++;
      // More still to come; the transfer ends on the last one, not this one.
      if (session.filesReceived < session.files.length) {
        return Response.ok('Received');
      }
    }

    _speedometer.stop();
    return _finishTransfer(session);
  }

  /// Runs [receive], turning the ways receiving can fail into the response the
  /// sender sees and the state this device publishes.
  ///
  /// Returns null when the bytes arrived, so a caller can carry on.
  Future<Response?> _receiveGuarded(
    _Session session,
    Future<void> Function() receive,
  ) async {
    try {
      await receive();
      return null;
    } on TimeoutException {
      _finishFailed(session, TransferFailure.timeout);
      return Response(408, body: 'The sender stopped responding');
    } on FileSystemException catch (e, s) {
      log('Could not write received files', error: e, stackTrace: s);
      _finishFailed(session, TransferFailure.storageError);
      return Response.internalServerError(body: 'Could not save the files');
    } catch (e, s) {
      log('Receiving failed', error: e, stackTrace: s);
      _finishFailed(session, TransferFailure.unknown);
      return Response.internalServerError(body: 'Transfer failed');
    }
  }

  /// As [_publishEnding], for a caller that owes the sender a response.
  Response _finishTransfer(_Session session) {
    final cancelled = session.cancelled;
    _publishEnding(session);
    return cancelled
        ? Response.badRequest(body: 'Cancelled')
        : Response.ok('File uploaded');
  }

  /// Publishes the ending for a transfer whose bytes have all arrived, or that
  /// somebody gave up on, and releases the session.
  void _publishEnding(_Session session) {
    final transport = session.transport;
    if (transport != null && session.clock.isRunning) {
      session.clock.stop();
      TransferDiagnostics.instance.recordReceived(
        TransferReport(
          transport: transport,
          bytes: session.nativeCounted > 0
              ? session.nativeCounted
              : session.totalSize,
          elapsed: session.clock.elapsed,
        ),
      );
    }

    final cancelledBy = session.cancelledBy;
    if (cancelledBy != null) {
      session.hangUp();
      _endSession(
        session,
        TransferCancelled(sessionId: session.id, by: cancelledBy),
      );
      return;
    }

    session.send(CompletedFrame(sessionId: session.id));
    session.hangUp();
    _endSession(session, TransferCompleted(sessionId: session.id));
  }

  /// Turns what the native data plane reports into the same states and control
  /// frames the Dart handlers publish, so nothing above this class can tell
  /// which one carried the bytes.
  void _onDataPlaneEvent(DataPlaneEvent event) {
    final session = _session;
    // Only arrivals. A device sending at the same time puts its own progress on
    // this stream, and in a test where both ends share a process every event
    // would otherwise be counted twice.
    if (event.sending ||
        session == null ||
        session.id != event.session ||
        !session.accepted) {
      return;
    }

    switch (event) {
      case DataPlaneProgress(:final index, :final transferred):
        if (!session.uploading) {
          session.uploading = true;
          session.transport = Transport.native;
          session.clock.start();
          _speedometer.reset();
          _speedometer.fileSize = session.totalSize;
        }

        session.nativeBytes[index] = transferred;
        final total = session.nativeBytes.values.fold(0, (a, b) => a + b);
        if (total > session.nativeCounted) {
          _speedometer.count(total - session.nativeCounted);
          session.nativeCounted = total;
        }

        final fileName = _offeredName(session, index);
        if (session.nativeIndex != index) {
          session.nativeIndex = index;
          _emit(
            session,
            TransferInProgress(
              sessionId: session.id,
              peerAddress: session.peerAddress,
              fileName: fileName,
            ),
          );
        }
        session.send(
          ProgressFrame(
            sessionId: session.id,
            bytesReceived: total,
            fileName: fileName,
          ),
        );

      case DataPlaneFileFinished(:final index):
        // Settle this file at its full size: the last progress event may have
        // been throttled away, and the total must not end short.
        if (index < session.files.length) {
          session.nativeBytes[index] = session.files[index].size;
          final total = session.nativeBytes.values.fold(0, (a, b) => a + b);
          if (total > session.nativeCounted) {
            _speedometer.count(total - session.nativeCounted);
            session.nativeCounted = total;
          }
        }

        session.filesReceived++;
        if (session.filesReceived >= session.files.length) {
          _speedometer.stop();
          _publishEnding(session);
        }

      case DataPlaneFailed(:final message):
        log('Data plane refused or lost a transfer: $message');
        _speedometer.stop();
        _finishFailed(session, TransferFailure.unknown);

      case DataPlaneCancelled():
        _speedometer.stop();
        session.cancelledBy ??= CancelledBy.sender;
        _publishEnding(session);
    }
  }

  String? _offeredName(_Session session, int index) =>
      index < session.files.length
      ? safeFileName(session.files[index].name)
      : null;

  void _finishFailed(_Session session, TransferFailure reason) {
    session.send(FailedFrame(sessionId: session.id, reason: reason));
    session.hangUp();
    _endSession(session, TransferFailed(sessionId: session.id, reason: reason));
  }

  /// Writes one raw-body request straight to [destination].
  ///
  /// No buffer between the socket and the sink. Coalescing writes to a
  /// megabyte first measured at about 3% here, which does not pay for extra
  /// state in a path that must not lose bytes. See `tool/transfer_bench.dart`.
  Future<void> _receiveBlob(
    Request request,
    _Session session,
    File destination,
    OfferedFile offered,
    String fileName,
  ) async {
    final sink = destination.openWrite();
    var complete = false;
    var received = 0;
    var lastProgress = DateTime.now();

    try {
      await for (final chunk in request.read().timeout(_chunkTimeout)) {
        if (session.cancelled) return;

        received += chunk.length;
        // A sender that keeps going past the size it offered is either broken
        // or trying to fill the disk.
        if (received > offered.size) {
          throw const FormatException('Sender exceeded the size it offered');
        }

        if (!disableFileWrite) sink.add(chunk);
        _speedometer.count(chunk.length);

        final now = DateTime.now();
        if (now.difference(lastProgress) >= _progressInterval) {
          lastProgress = now;
          session.send(
            ProgressFrame(
              sessionId: session.id,
              bytesReceived:
                  _speedometer.readingStream.value?.totalBytesTransferred ?? 0,
              fileName: fileName,
            ),
          );
        }
      }

      // A body that stops early leaves a file that is not what was offered.
      // Better to fail the transfer than to hand over a truncated file that
      // looks finished.
      if (received < offered.size) {
        throw const FormatException('Sender sent less than it offered');
      }

      await sink.flush();
      complete = true;
    } finally {
      try {
        await sink.close();
      } catch (_) {
        // Closing re-throws whatever already broke the write; that error is on
        // its way up and must not be masked by this one.
      }
      if (!complete) await _deleteQuietly(destination);
    }
  }

  /// Where to put an incoming [fileName] without destroying anything already
  /// there. A second "photo.jpg" lands as "photo (1).jpg".
  Future<File> _unusedPathFor(
    String fileName, {
    Set<String> claimed = const {},
  }) async {
    final extension = path.extension(fileName);
    final stem = path.basenameWithoutExtension(fileName);

    var candidate = File(path.join(_downloadPath, fileName));
    var suffix = 0;
    while (await candidate.exists() || claimed.contains(candidate.path)) {
      suffix++;
      candidate = File(path.join(_downloadPath, '$stem ($suffix)$extension'));
    }
    return candidate;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      log('Left behind a partial file at ${file.path}', error: e);
    }
  }

  void _emit(_Session session, TransferState state) {
    if (_stateSessionId != session.id) return;
    _transferStateSubject.add(state);
  }

  /// Publishes [last] for [session] and releases the slot so the next sender
  /// can be served.
  void _endSession(_Session session, TransferState last) {
    // Retires the token on the native side too, so it cannot be replayed once
    // the exchange it belonged to is over.
    unawaited(DataPlane.instance.closeSession(session.id));
    _emit(session, last);
    if (_stateSessionId == session.id) _stateSessionId = null;
    if (identical(_session, session)) _session = null;
  }

  /// Abandons any transfer in flight and returns to idle.
  void reset() {
    final session = _session;
    if (session != null) {
      session.cancelledBy = CancelledBy.receiver;
      if (!session.closed) {
        session.send(CancelFrame(sessionId: session.id));
        session.hangUp();
      }
    }
    _session = null;
    _stateSessionId = null;
    _speedometer.reset();
    _transferStateSubject.add(const TransferIdle());
  }

  /// Closes server and it can't be used without starting it again.
  void close() {
    reset();
    unawaited(_dataPlaneEvents?.cancel());
    _dataPlaneEvents = null;
    unawaited(DataPlane.instance.stopServer());
    _dataPort = null;
    _server?.close();
    _server = null;
  }
}

/// The name a peer asked for, reduced to something that can only land inside
/// the download directory.
///
/// The name comes out of the offer, which the sender wrote. `path.join` returns
/// an absolute path unchanged and honours `..`, so without this an accepted
/// peer could write anywhere this process can reach — over a dotfile, into a
/// config directory, anywhere.
///
/// Both separators are stripped whatever the host platform, since the name
/// crosses between machines and a Windows sender's backslashes mean nothing to
/// `path.basename` on POSIX.
String safeFileName(String? requested) {
  final flattened = (requested ?? '').replaceAll(r'\', '/');
  final base = flattened.split('/').last.trim();

  if (base.isEmpty || base == '.' || base == '..') return 'file';
  // a leading dot would hide the file, which a sender should not get to decide
  return base.startsWith('.') ? base.substring(1) : base;
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
