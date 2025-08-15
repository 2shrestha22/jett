import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/transfer/speedometer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class Client {
  final VoidCallback? onUploadStart;
  final VoidCallback? onUploadFinish;

  Client({this.onUploadStart, this.onUploadFinish});

  final _httpClient = HttpClient();
  final _speedometer = Speedometer();

  Stream<SpeedometerReading?> get speedometerReadingsStream =>
      _speedometer.readingStream;
  SpeedometerReading? get speedometerReadings => _speedometer.reading;

  /// Retruns true if the transfer request is accepted by the receiver.
  Future<bool> requestUpload(String ipAddr) async {
    final uri = Uri.parse('http://$ipAddr:$kTcpPort/request');
    final response = await http.get(uri);

    return response.statusCode == 200;
  }

  /// Uploads files to the specified IP address.
  ///
  /// You should only upload files after the transfer request is accepted.
  Future<void> upload(List<PlatformFile> files, String ipAddr) async {
    _speedometer.reset();

    final totalSize = files.fold(
      0,
      (previousValue, element) => previousValue + element.size,
    );
    _speedometer.fileSize = totalSize;

    final uri = Uri.parse('http://$ipAddr:$kTcpPort/upload');
    final httpClientRequest = await _httpClient.postUrl(uri);

    final requestMultipart = http.MultipartRequest('POST', uri);
    for (var file in files) {
      requestMultipart.files.add(
        http.MultipartFile(
          'files',
          file.readStream!,
          file.size,
          filename: file.name,
          contentType: _getContentType(file.path),
        ),
      );
    }

    final multipartRequestStream = requestMultipart.finalize();

    httpClientRequest.headers.set('x-file-size', totalSize.toString());
    // content type header is only avaiable after finalizing the request
    final multipartHeader =
        requestMultipart.headers[HttpHeaders.contentTypeHeader];
    if (multipartHeader != null) {
      httpClientRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        multipartHeader,
      );
    }

    final Stream<List<int>> streamUpload = multipartRequestStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
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

    onUploadStart?.call();
    await httpClientRequest.addStream(streamUpload);
    final httpResponse = await httpClientRequest.close();

    if (httpResponse.statusCode == 200) {
      await _readResponseAsString(httpResponse);
    } else {
      throw Exception('Failed to upload files: ${httpResponse.statusCode}');
    }
    onUploadFinish?.call();
  }
}

Future<String> _readResponseAsString(HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen((String data) {
    contents.write(data);
  }, onDone: () => completer.complete(contents.toString()));

  return completer.future;
}

MediaType? _getContentType(String? filePath) {
  final mimeType = filePath != null ? lookupMimeType(filePath) : null;
  final contentType = mimeType != null ? MediaType.parse(mimeType) : null;

  return contentType;
}
