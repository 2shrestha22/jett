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

  final _metadataSubject = BehaviorSubject<TransferMetadata?>();
  Stream<TransferMetadata?> get transferMetadata => _metadataSubject.stream;

  final VoidCallback onStart;
  final Future<bool> Function(String? clientAddress) onRequest;
  final VoidCallback onComplete;

  String _senderIp = '';

  Server({
    required this.onStart,
    required this.onComplete,
    required this.onRequest,
  });

  Future<void> start() async {
    _downloadPath = await getSavePath();
    await File(path.join(_downloadPath, '.test')).writeAsString('');

    _router.post('/upload', _handleUpload);
    _router.get('/request', _handleRequest);
    _server = await io.serve(_router.call, InternetAddress.anyIPv4, kTcpPort);
  }

  Future<Response> _handleUpload(Request request) async {
    final fileSizeHeader = request.headers['x-file-size'];
    int totalFileSize = int.parse(fileSizeHeader!);

    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.startsWith('multipart/form-data')) {
      return Response(400, body: 'Unsupported content type');
    }

    if (_getClientAddress(request) != _senderIp) {
      return Response.forbidden('Transfer not accepted from this IP');
    }
    _senderIp = '';

    onStart.call();
    if (request.formData() case var form?) {
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

    onComplete();
    _metadataSubject.add(null);

    return Response.ok('File uploaded');
  }

  Future<Response> _handleRequest(Request request) async {
    final clientAddress = _getClientAddress(request);
    final accepted = await onRequest(clientAddress);

    if (!accepted) {
      return Response.forbidden('Transfer not accepted');
    }

    _senderIp = clientAddress;
    return Response.ok('Request accepted');
  }

  void close() {
    _server?.close();
    _server = null;
    _senderIp = '';
    _metadataSubject.close();
  }
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
