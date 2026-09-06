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
  final _speedometer = Speedometer();

  ValueStream<SpeedometerReading?> get speedometerReadingsStream =>
      _speedometer.readingStream;

  final _fileNameSubject = BehaviorSubject<String>();
  Stream<String> get fileNameStream => _fileNameSubject.stream.distinct();

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    TransferState.idle,
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  Completer<void>? _abortTrigger;

  /// Identifies the current transfer attempt. Emissions from an attempt that
  /// has since been superseded or reset are dropped, so a stale result can
  /// never overwrite the state of a newer one.
  int _session = 0;

  /// Asks [ipAddr] to accept a transfer and, once accepted, uploads
  /// [resources]. The transfer runs in the background so the caller can show
  /// progress while it happens.
  ///
  /// Returns false without starting anything when a transfer is already
  /// active; the caller should not navigate to the transfer screen in that
  /// case.
  bool startUpload(List<Resource> resources, String ipAddr) {
    if (_transferStateSubject.value != TransferState.idle) return false;

    final session = ++_session;
    _abortTrigger = Completer<void>();
    _emit(session, TransferState.waiting);
    unawaited(_run(session, resources, ipAddr));
    return true;
  }

  Future<void> _run(
    int session,
    List<Resource> resources,
    String ipAddr,
  ) async {
    final httpClient = http.Client();
    try {
      final uri = Uri.parse('http://$ipAddr:$kTcpPort/request');
      final response = await httpClient
          .get(uri)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        _emit(session, TransferState.failed);
        return;
      }

      _emit(session, TransferState.inProgress);
      await _upload(session, resources, ipAddr);
    } catch (e, s) {
      log('Transfer failed', error: e, stackTrace: s);
      _emit(session, TransferState.failed);
    } finally {
      httpClient.close();
      _speedometer.stop();
    }
  }

  void _emit(int session, TransferState state) {
    if (session != _session) return;
    _transferStateSubject.add(state);
  }

  void _abort() {
    final trigger = _abortTrigger;
    if (trigger != null && !trigger.isCompleted) trigger.complete();
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> _upload(
    int session,
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
            _fileNameSubject.add(resource.name);
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
      _emit(session, TransferState.completed);
    } else {
      _emit(session, TransferState.failed);
    }
  }

  /// Aborts any in-flight transfer and returns to [TransferState.idle] so a new
  /// transfer can be started.
  void reset() {
    // invalidate the running attempt so its result cannot land after this
    _session++;
    _abort();
    _abortTrigger = null;
    _speedometer.reset();
    _transferStateSubject.add(TransferState.idle);
  }
}

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
