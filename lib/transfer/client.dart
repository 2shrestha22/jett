import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/resource.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';

final client = Client();

class Client {
  /// How long the receiving device is given to answer the request before we
  /// assume nobody is going to.
  static const _acceptTimeout = Duration(minutes: 2);

  final _speedometer = Speedometer();

  ValueStream<SpeedometerReading?> get speedometerReadingsStream =>
      _speedometer.readingStream;

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    const TransferIdle(),
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  Completer<void>? _abortTrigger;

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

    final session = '${++_sessionCounter}';
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
    final httpClient = http.Client();
    try {
      final uri = Uri.parse('http://$ipAddr:$kTcpPort/request');
      final response = await httpClient.get(uri).timeout(_acceptTimeout);

      if (response.statusCode != 200) {
        _fail(session, _failureForStatus(response.statusCode));
        return;
      }

      _emit(
        session,
        TransferInProgress(sessionId: session, peerAddress: ipAddr),
      );
      await _upload(session, resources, ipAddr);
    } on TimeoutException {
      _fail(session, TransferFailure.timeout);
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
      httpClient.close();
      _speedometer.stop();
    }
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> _upload(
    String session,
    List<Resource> resources,
    String ipAddr,
  ) async {
    // user already cancelled send, using reset()
    if (_abortTrigger == null) return;

    _speedometer.reset();

    int totalFileSize = 0;
    final uri = Uri.parse('http://$ipAddr:$kTcpPort/upload');

    final streamedRequest = http.AbortableStreamedRequest(
      'POST',
      uri,
      abortTrigger: _abortTrigger?.future,
    );

    // create a multipart request body stream
    // and add speedometer counting to each file stream
    final requestMultipart = http.MultipartRequest('POST', uri);
    for (var resource in resources) {
      final contentLenght = await resource.length();

      if (contentLenght == null) {
        throw FileSystemException('Cannot read file', resource.identifier);
      }

      totalFileSize += contentLenght;

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
          contentLenght,
          filename: resource.name,
          contentType: _getContentType(resource.mimeType),
        ),
      );
    }
    _speedometer.fileSize = totalFileSize;
    final multipartRequestBodyStream = requestMultipart.finalize();

    streamedRequest.headers.addAll({'x-file-size': totalFileSize.toString()});
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

  void _emit(String session, TransferState state) {
    if (_stateSessionId != session) return;
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
