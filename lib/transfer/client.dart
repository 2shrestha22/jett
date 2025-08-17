import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/file_info.dart';
import 'package:anysend/transfer/speedometer.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:rxdart/subjects.dart';
import 'package:uri_content/uri_content.dart';

class Client {
  final VoidCallback? onUploadStart;
  final VoidCallback? onUploadFinish;

  Client({this.onUploadStart, this.onUploadFinish});

  // final _httpClient = HttpClient();
  final _speedometer = Speedometer();
  final _uriContent = UriContent();

  Stream<SpeedometerReading?> get speedometerReadingsStream =>
      _speedometer.readingStream;
  SpeedometerReading? get speedometerReadings => _speedometer.reading;

  final _fileNameSubject = BehaviorSubject<String>();
  Stream<String> get fileNameStream => _fileNameSubject.stream.distinct();

  /// Retruns true if the transfer request is accepted by the receiver.
  Future<bool> requestUpload(String ipAddr) async {
    final uri = Uri.parse('http://$ipAddr:$kTcpPort/request');
    final response = await http.get(uri);

    return response.statusCode == 200;
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> upload(
    List<FileInfo> files,
    String ipAddr,
    Future<void> abortTrigger,
  ) async {
    _speedometer.reset();
    onUploadStart?.call();

    int totalFileSize = 0;
    final uri = Uri.parse('http://$ipAddr:$kTcpPort/upload');

    final streamedRequest = http.AbortableStreamedRequest(
      'POST',
      uri,
      abortTrigger: abortTrigger,
    );

    // create a multipart request body stream
    // and add speedometer counting to each file stream
    final requestMultipart = http.MultipartRequest('POST', uri);
    for (var file in files) {
      // TODO: in linux and windows URI is null and should be handled
      // differently using file path
      final size =
          await _uriContent.getContentLength(Uri.parse(file.uri!)) ?? 0;
      totalFileSize += size;
      final fileStream = _uriContent
          .getContentStream(Uri.parse(file.uri!))
          .transform(
            StreamTransformer<Uint8List, Uint8List>.fromHandlers(
              handleData: (data, sink) {
                sink.add(data);
                _fileNameSubject.add(file.name);
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
          size,
          filename: file.name,
          contentType: _getContentType(file.path),
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
    } else {
      throw Exception('Failed to upload files: ${httpResponse.statusCode}');
    }
    onUploadFinish?.call();
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

MediaType? _getContentType(String? filePath) {
  final mimeType = filePath != null ? lookupMimeType(filePath) : null;
  final contentType = mimeType != null ? MediaType.parse(mimeType) : null;

  return contentType;
}
