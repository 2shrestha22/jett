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
  final void Function(double speedMbps)? onComplete;

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

    final stopwatch = Stopwatch()..start();
    // Keep last chunks for rolling average
    final List<_ChunkData> recentChunks = [];
    const rollingWindowMs = 2000; // 2 second window

    Stream<List<int>> streamUpload = multipartRequestStream.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          byteCount += data.length;

          // Record chunk
          recentChunks.add(
            _ChunkData(
              size: data.length,
              timestamp: stopwatch.elapsedMilliseconds,
            ),
          );

          // Remove old chunks outside rolling window
          final cutoff = stopwatch.elapsedMilliseconds - rollingWindowMs;
          while (recentChunks.isNotEmpty &&
              recentChunks.first.timestamp < cutoff) {
            recentChunks.removeAt(0);
          }

          // Calculate rolling average speed (bytes/sec)
          final totalBytesRecent = recentChunks.fold<int>(
            0,
            (sum, chunk) => sum + chunk.size,
          );
          final elapsedRecentMs =
              (recentChunks.last.timestamp - recentChunks.first.timestamp)
                  .clamp(1, rollingWindowMs); // avoid divide-by-zero
          final speedBps = totalBytesRecent / (elapsedRecentMs / 1000.0);
          final speedMbps = (speedBps * 8) / (1024 * 1024);

          _metadataSubject.add(
            TransferMetadata(
              fileName: '', //unable to get file name here
              totalSize: totalSize,
              transferredBytes: byteCount,
              speedMbps: speedMbps,
            ),
          );
        },
        handleError: (error, stack, sink) {
          throw error;
        },
        handleDone: (sink) {
          stopwatch.stop();
          sink.close();
        },
      ),
    );
    onStart?.call();
    await httpClientRequest.addStream(streamUpload);

    final httpResponse = await httpClientRequest.close();

    if (httpResponse.statusCode == 200) {
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      final avgSpeedBps = byteCount / elapsedSeconds;
      final avgSpeedMbps = (avgSpeedBps * 8) / (1024 * 1024);
      onComplete?.call(avgSpeedMbps);

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

class _ChunkData {
  final int size; // bytes
  final int timestamp; // ms since upload start
  _ChunkData({required this.size, required this.timestamp});
}
