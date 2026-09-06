import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/save_path.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';

const disableFileWrite = kDebugMode;

final server = Server();

/// One incoming transfer, from the moment the sender asks until it finishes.
class _Session {
  final String id;
  final String peerAddress;

  /// Replaced when the same peer re-sends its request, which supersedes the
  /// earlier one without disturbing the prompt already on screen.
  Completer<bool> acceptance = Completer<bool>();

  /// Set once the user has approved; only then may the sender upload.
  bool accepted = false;

  /// Set once bytes start arriving. Until then the peer is still free to
  /// restart its request.
  bool uploading = false;

  /// Set when the receiving side gives up, which stops the file loop.
  bool cancelled = false;

  _Session(this.id, this.peerAddress);
}

class Server {
  /// How long the sender is kept waiting before we assume nobody is at the
  /// receiving device. Generous, because someone has to notice and respond.
  static const _acceptTimeout = Duration(minutes: 2);

  /// How long a stalled upload is tolerated before the transfer is failed.
  static const _chunkTimeout = Duration(seconds: 10);

  /// How long an accepted transfer may sit before any bytes arrive. Guards
  /// against a sender that disappears between being accepted and uploading,
  /// which would otherwise hold the slot against every other peer.
  static const _uploadStartTimeout = Duration(seconds: 30);

  final _router = Router();
  HttpServer? _server;

  late String _downloadPath;

  final _speedometer = Speedometer();
  ValueStream<SpeedometerReading?> get speedometerReadingStream =>
      _speedometer.readingStream;

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    const TransferIdle(),
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  _Session? _session;
  int _sessionCounter = 0;

  /// Whose states are currently being published. Emissions from any other
  /// session are dropped, so a superseded attempt cannot overwrite a newer one.
  String? _stateSessionId;

  String get senderIp => _session?.peerAddress ?? '';

  Future<void> start() async {
    _downloadPath = await getSavePath();

    _router
      ..get('/request', _handleRequest)
      ..post('/upload', _handleUpload);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, kTcpPort);
  }

  void acceptRequest() => _answer(true);
  void rejectRequest() => _answer(false);

  void _answer(bool accepted) {
    final session = _session;
    if (session == null || session.acceptance.isCompleted) return;
    session.acceptance.complete(accepted);
  }

  Future<Response> _handleRequest(Request request) async {
    final peer = _getClientAddress(request);
    final current = _session;

    // Only a peer that restarted its own request before any bytes moved may
    // take over; everyone else waits their turn.
    if (current != null && (current.uploading || current.peerAddress != peer)) {
      return Response(409, body: 'Another transfer is in progress');
    }

    final _Session session;
    if (current != null && !current.accepted) {
      // Still on the same prompt, so reuse the session and let the dialog
      // already on screen answer this newer request instead of asking twice.
      session = current;
      if (!session.acceptance.isCompleted) session.acceptance.complete(false);
      session.acceptance = Completer<bool>();
    } else {
      if (current != null && !current.acceptance.isCompleted) {
        current.acceptance.complete(false);
      }
      session = _Session('${++_sessionCounter}', peer);
      _session = session;
      _stateSessionId = session.id;
      _transferStateSubject.add(
        TransferWaiting(sessionId: session.id, peerAddress: peer),
      );
    }

    final acceptance = session.acceptance;
    final bool accepted;
    try {
      accepted = await acceptance.future.timeout(_acceptTimeout);
    } on TimeoutException {
      _endSession(session, const TransferIdle());
      return Response(408, body: 'No answer from the receiving device');
    }

    // A newer request from the same peer took this session over; this call is
    // only here to unblock the connection it arrived on.
    if (!identical(session.acceptance, acceptance)) {
      return Response(409, body: 'Superseded by a newer request');
    }

    if (!accepted) {
      // Declining is not a failure on this side; drop straight back to idle.
      _endSession(session, const TransferIdle());
      return Response.forbidden('Transfer declined');
    }

    session.accepted = true;
    Timer(_uploadStartTimeout, () {
      if (!identical(_session, session) || session.uploading) return;
      _endSession(session, const TransferIdle());
    });
    return Response.ok('Request accepted');
  }

  Future<Response> _handleUpload(Request request) async {
    final session = _session;
    final peer = _getClientAddress(request);

    if (session == null || !session.accepted || session.peerAddress != peer) {
      return Response.forbidden('No accepted transfer for this peer');
    }

    final totalFileSize = int.tryParse(request.headers['x-file-size'] ?? '');
    if (totalFileSize == null) {
      return Response(400, body: 'Missing or invalid x-file-size header');
    }

    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.startsWith('multipart/form-data')) {
      return Response(400, body: 'Unsupported content type');
    }

    session.uploading = true;
    _speedometer.reset();
    _speedometer.fileSize = totalFileSize;
    _emit(
      session,
      TransferInProgress(sessionId: session.id, peerAddress: peer),
    );

    try {
      await _receiveFiles(request, session);
    } on TimeoutException {
      _endSession(session, _failure(session, TransferFailure.timeout));
      return Response(408, body: 'The sender stopped responding');
    } on FileSystemException catch (e, s) {
      log('Could not write received files', error: e, stackTrace: s);
      _endSession(session, _failure(session, TransferFailure.storageError));
      return Response.internalServerError(body: 'Could not save the files');
    } catch (e, s) {
      log('Receiving failed', error: e, stackTrace: s);
      _endSession(session, _failure(session, TransferFailure.unknown));
      return Response.internalServerError(body: 'Transfer failed');
    } finally {
      _speedometer.stop();
    }

    if (session.cancelled) {
      _endSession(
        session,
        TransferCancelled(sessionId: session.id, by: CancelledBy.receiver),
      );
      return Response.badRequest(body: 'Cancelled on the receiving device');
    }

    _endSession(session, TransferCompleted(sessionId: session.id));
    return Response.ok('File uploaded');
  }

  Future<void> _receiveFiles(Request request, _Session session) async {
    if (request.formData() case var form?) {
      await for (final data in form.formData) {
        if (data.name != 'files') continue;
        if (session.cancelled) return;

        final fileName = data.filename ?? 'file';
        final destination = File(path.join(_downloadPath, fileName));
        _emit(
          session,
          TransferInProgress(
            sessionId: session.id,
            peerAddress: session.peerAddress,
            fileName: fileName,
          ),
        );

        final sink = destination.openWrite();
        var complete = false;
        try {
          await for (final chunk in data.part.timeout(_chunkTimeout)) {
            if (session.cancelled) return;
            if (!disableFileWrite) sink.add(chunk);
            _speedometer.count(chunk.length);
          }
          await sink.flush();
          complete = true;
        } finally {
          try {
            await sink.close();
          } catch (_) {
            // Closing re-throws whatever already broke the write; that error
            // is on its way up and must not be masked by this one.
          }
          if (!complete) await _deleteQuietly(destination);
        }
      }
    }
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException catch (e) {
      log('Left behind a partial file at ${file.path}', error: e);
    }
  }

  TransferState _failure(_Session session, TransferFailure reason) =>
      TransferFailed(sessionId: session.id, reason: reason);

  void _emit(_Session session, TransferState state) {
    if (_stateSessionId != session.id) return;
    _transferStateSubject.add(state);
  }

  /// Publishes [last] for [session] and releases the slot so the next sender
  /// can be served.
  void _endSession(_Session session, TransferState last) {
    _emit(session, last);
    if (_stateSessionId == session.id) _stateSessionId = null;
    if (identical(_session, session)) _session = null;
  }

  /// Abandons any transfer in flight and returns to idle.
  void reset() {
    _session?.cancelled = true;
    _session = null;
    _stateSessionId = null;
    _speedometer.reset();
    _transferStateSubject.add(const TransferIdle());
  }

  /// Closes server and it can't be used without starting it again.
  void close() {
    reset();
    _server?.close();
    _server = null;
  }
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
