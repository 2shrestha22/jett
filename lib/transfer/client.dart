import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/protocol.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/device_info.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final client = Client();

/// A resource paired with the size it reported when the transfer was offered.
typedef _SizedResource = (Resource resource, int length);

class Client {
  /// How long to wait for the control socket to come up.
  static const _connectTimeout = Duration(seconds: 10);

  /// How long the receiving device is given to answer before we assume nobody
  /// is going to.
  static const _acceptTimeout = Duration(minutes: 2);

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

  /// Asks [ipAddr] to accept a transfer and, once accepted, uploads
  /// [resources]. The transfer runs in the background so the caller can show
  /// progress while it happens.
  ///
  /// Returns false without starting anything when a transfer is already
  /// active; the caller should not navigate to the transfer screen in that
  /// case.
  bool startUpload(List<Resource> resources, String ipAddr) {
    if (_transferStateSubject.value is! TransferIdle) return false;

    final session =
        '${DateTime.now().microsecondsSinceEpoch}-${++_sessionCounter}';
    _stateSessionId = session;
    _abortTrigger = Completer<void>();
    _currentFileName = null;

    _transferStateSubject.add(
      TransferWaiting(sessionId: session, peerAddress: ipAddr),
    );
    unawaited(_run(session, resources, ipAddr));
    return true;
  }

  Future<void> _run(
    String session,
    List<Resource> resources,
    String ipAddr,
  ) async {
    WebSocketChannel? socket;
    StreamSubscription<dynamic>? frames;

    try {
      socket = IOWebSocketChannel.connect(
        Uri.parse('ws://$ipAddr:$kTcpPort/ws'),
        connectTimeout: _connectTimeout,
      );
      await socket.ready;
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

      frames = socket.stream.listen(
        (raw) => _onFrame(session, raw, answer),
        onDone: () {
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
          if (!answer.isCompleted) answer.completeError(e);
          _abort();
        },
      );

      socket.sink.add(
        RequestFrame(
          sessionId: session,
          senderName: DeviceInfoHelper.deviceName,
          files: [
            for (final (resource, length) in sized)
              OfferedFile(
                name: resource.name,
                size: length,
                mimeType: resource.mimeType,
              ),
          ],
          totalSize: totalSize,
        ).toJson(),
      );

      final decision = await answer.future.timeout(_acceptTimeout);
      if (decision is DeclinedFrame) {
        _fail(session, decision.reason);
        return;
      }

      _emit(
        session,
        TransferInProgress(sessionId: session, peerAddress: ipAddr),
      );
      await _upload(session, sized, totalSize, ipAddr);
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
      _speedometer.stop();
    }
  }

  void _onFrame(String session, Object? raw, Completer<ControlMessage> answer) {
    final ControlMessage frame;
    try {
      frame = ControlMessage.fromJson(raw! as String);
    } catch (e) {
      log('Unreadable control frame', error: e);
      return;
    }
    if (frame.sessionId != session) return;

    switch (frame) {
      case AcceptedFrame() || DeclinedFrame():
        if (!answer.isCompleted) answer.complete(frame);
      case FailedFrame(:final reason):
        _fail(session, reason);
        _abort();
      case CancelFrame():
        _emit(
          session,
          TransferCancelled(sessionId: session, by: CancelledBy.receiver),
        );
        _abort();
      case CompletedFrame():
        // The receiver confirming it has everything is the authoritative
        // success signal, and it arrives before the upload response does.
        _emit(session, TransferCompleted(sessionId: session));
      case ProgressFrame() || RequestFrame():
        break;
    }
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> _upload(
    String session,
    List<_SizedResource> resources,
    int totalFileSize,
    String ipAddr,
  ) async {
    // user already cancelled send, using reset()
    if (_abortTrigger == null) return;

    _speedometer.reset();
    _speedometer.fileSize = totalFileSize;

    final uri = Uri.parse('http://$ipAddr:$kTcpPort/upload?session=$session');

    final streamedRequest = http.AbortableStreamedRequest(
      'POST',
      uri,
      abortTrigger: _abortTrigger?.future,
    );

    // create a multipart request body stream
    // and add speedometer counting to each file stream
    final requestMultipart = http.MultipartRequest('POST', uri);
    for (final (resource, contentLength) in resources) {
      final contentStream = resource.openRead().cast<List<int>>();
      final fileStream = contentStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            sink.add(data);
            if (_currentFileName != resource.name) {
              _currentFileName = resource.name;
              _emit(
                session,
                TransferInProgress(
                  sessionId: session,
                  peerAddress: ipAddr,
                  fileName: resource.name,
                ),
              );
            }
            _speedometer.count(data.length);
          },
          handleError: (error, stack, sink) => sink.addError(error, stack),
          handleDone: (sink) => sink.close(),
        ),
      );
      requestMultipart.files.add(
        http.MultipartFile(
          'files',
          fileStream,
          contentLength,
          filename: resource.name,
          contentType: _getContentType(resource.mimeType),
        ),
      );
    }
    final multipartRequestBodyStream = requestMultipart.finalize();

    // content type header is only avaiable after finalizing the request
    final multipartHeader =
        requestMultipart.headers[HttpHeaders.contentTypeHeader];
    if (multipartHeader != null) {
      streamedRequest.headers.addAll({
        HttpHeaders.contentTypeHeader: multipartHeader,
      });
    }

    unawaited(
      streamedRequest.sink
          .addStream(multipartRequestBodyStream)
          .catchError((Object e, StackTrace s) {
            log('Request body stream failed', error: e, stackTrace: s);
            // unblock send(), which would otherwise wait on a body that will
            // never arrive
            _abort();
          })
          .whenComplete(streamedRequest.sink.close),
    );
    final httpResponse = await streamedRequest.send();

    if (httpResponse.statusCode == 200) {
      final response = await _readResponseAsString(httpResponse);
      log(response);
      _emit(session, TransferCompleted(sessionId: session));
    } else {
      _fail(session, _failureForStatus(httpResponse.statusCode));
    }
  }

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

Future<String> _readResponseAsString(http.StreamedResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.stream.transform(utf8.decoder).listen((String data) {
    contents.write(data);
  }, onDone: () => completer.complete(contents.toString()));

  return completer.future;
}

MediaType? _getContentType(String? mimeType) {
  final contentType = mimeType != null ? MediaType.parse(mimeType) : null;

  return contentType;
}
