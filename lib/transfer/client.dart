import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/transfer_metadata.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/subjects.dart';

class Client {
  final _httpClient = HttpClient();

  final _metadataSubject = BehaviorSubject<TransferMetadata>();
  Stream<TransferMetadata> get transferMetadata => _metadataSubject.stream;

  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  Client({this.onStart, this.onComplete});

  void upload(List<PlatformFile> files, String ipAddress) async {
    int byteCount = 0;
    // final totalSize = await getFilesSize(files);
    final totalSize = files.fold(
      0,
      (previousValue, element) => previousValue + element.size,
    );

    final uri = Uri.parse('http://$ipAddress:$kTcpPort/upload');
    final httpClientRequest = await _httpClient.postUrl(uri);

    final requestMultipart = http.MultipartRequest('POST', uri);

    for (var file in files) {
      requestMultipart.files.add(
        await http.MultipartFile.fromPath('files', file.path!),
      );
    }

    final multipartRequestStream = requestMultipart.finalize();

    httpClientRequest.headers.set('x-file-size', totalSize.toString());
    // content type header is only avaiable after finalizing the request
    httpClientRequest.headers.set(
      HttpHeaders.contentTypeHeader,
      requestMultipart.headers[HttpHeaders.contentTypeHeader]!,
    );

    Stream<List<int>> streamUpload = multipartRequestStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);

          byteCount += data.length;
          _metadataSubject.add(
            TransferMetadata(
              fileName: '', //unable to get file name here
              totalSize: totalSize,
              transferredBytes: byteCount,
            ),
          );
        },
        handleError: (error, stack, sink) {
          throw error;
        },
        handleDone: (sink) {
          sink.close();
        },
      ),
    );
    onStart?.call();
    await httpClientRequest.addStream(streamUpload);

    final httpResponse = await httpClientRequest.close();

    if (httpResponse.statusCode == 200) {
      onComplete?.call();
      return readResponseAsString(httpResponse).then((response) {
        log('Upload complete: $response');
      });
    } else {
      throw Exception('Failed to upload files: ${httpResponse.statusCode}');
    }
  }

  static Future<String> readResponseAsString(HttpClientResponse response) {
    final completer = Completer<String>();
    final contents = StringBuffer();
    response.transform(utf8.decoder).listen((String data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }
}

Future<int> getFilesSize(List<File> files) async {
  return files.fold(0, (total, file) async {
    return await total + await file.length();
  });
}
