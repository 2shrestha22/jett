import 'dart:io';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/transfer_metadata.dart';
import 'package:anysend/utils/save_path.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/subjects.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as path;

class Server {
  final _router = Router();
  HttpServer? _server;

  late String _downloadPath;

  final _metadataSubject = BehaviorSubject<TransferMetadata>();
  Stream<TransferMetadata> get transferMetadata => _metadataSubject.stream;

  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  Server({this.onStart, this.onComplete});

  Future<void> start() async {
    _router.post('/upload', _handleUpload);
    _downloadPath = await getSavePath();
    await File(path.join(_downloadPath, '.test')).writeAsString('');
    _server = await io.serve(_router.call, '0.0.0.0', kTcpPort);
  }

  Future<Response> _handleUpload(Request request) async {
    final contentType = request.headers['content-type'];
    final fileSizeHeader = request.headers['x-file-size'];
    int totalFileSize = int.parse(fileSizeHeader!);

    if (contentType == null || !contentType.startsWith('multipart/form-data')) {
      return Response(400, body: 'Unsupported content type');
    }

    if (request.formData() case var form?) {
      onStart?.call();
      int bytesWritten = 0;
      await for (final data in form.formData) {
        if (data.name == 'files') {
          final fileName = data.filename ?? 'file';
          final destinationFile = File('$_downloadPath/$fileName');
          final sink = destinationFile.openWrite();
          await for (final chunk in data.part) {
            bytesWritten += chunk.length;
            sink.add(chunk);
            _metadataSubject.add(
              TransferMetadata(
                fileName: fileName,
                totalSize: totalFileSize,
                transferredBytes: bytesWritten,
              ),
            );
          }
          await sink.flush();
          await sink.close();
        }
      }
    }

    onComplete?.call();
    return Response.ok('File uploaded');
  }

  void close() {
    _server?.close();
    _server = null;
    _metadataSubject.close();
  }
}
