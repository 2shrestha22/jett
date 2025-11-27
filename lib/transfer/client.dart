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

  // final _transferStatus = BehaviorSubject<TransferStatus>();
  // Stream<TransferStatus> get transferStatus =>
  //     _transferStatus.stream.distinct();

  /// Retruns true if the transfer request is accepted by the receiver.
  Future<void> requestUpload(List<Resource> resources, String ipAddr) async {
    _transferStateSubject.add(TransferState.waiting);
    _abortTrigger = Completer<void>();

    final uri = Uri.parse('http://$ipAddr:$kTcpPort/request');
    final response = await http.Client().get(uri);

    if (response.statusCode == 200) {
      _transferStateSubject.add(TransferState.inProgress);
      await _upload(resources, ipAddr);
    } else {
      _transferStateSubject.add(TransferState.failed);
    }
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> _upload(List<Resource> resources, String ipAddr) async {
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

      if (contentLenght == null) return;

      totalFileSize += contentLenght;

      final contentStream = resource.openRead().cast<List<int>>();
      final fileStream = contentStream.transform(
        StreamTransformer<List<int>, List<int>>.fromHandlers(
          handleData: (data, sink) {
            sink.add(data);
            _fileNameSubject.add(resource.name);
            _speedometer.count(data.length);
          },
          handleError: (error, stack, sink) {
            _speedometer.stop();
            throw error;
          },
          handleDone: (sink) {
            _speedometer.stop();
            sink.close();
          },
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
          .then((_) => streamedRequest.sink.close()),
    );
    final httpResponse = await streamedRequest.send();

    if (httpResponse.statusCode == 200) {
      final response = await _readResponseAsString(httpResponse);
      log(response);
      _transferStateSubject.add(TransferState.completed);
    } else {
      _transferStateSubject.add(TransferState.failed);
    }
  }

  /// Reset speedometer readings and session
  void reset() {
    _speedometer.reset();
    _abortTrigger?.complete();
    _abortTrigger = null;
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
