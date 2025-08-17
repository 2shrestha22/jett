import 'dart:io';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/transfer/speedometer.dart';
import 'package:anysend/utils/save_path.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/subjects.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as path;

class Server {
  final Future<bool> Function(String clientAddress) onRequest;
  final VoidCallback onDownloadStart;
  final VoidCallback onDownloadFinish;

  Server({
    required this.onDownloadStart,
    required this.onDownloadFinish,
    required this.onRequest,
  });

  final _router = Router();
  HttpServer? _server;

  late String _downloadPath;

  final _speedometer = Speedometer();
  Stream<SpeedometerReading?> get speedometerReadingStream =>
      _speedometer.readingStream;
  SpeedometerReading? get speedometerReading => _speedometer.reading;

  final _fileNameSubject = BehaviorSubject<String>();
  Stream<String> get fileNameStream => _fileNameSubject.stream.distinct();

  String _senderIp = '';

  Future<void> start() async {
    _downloadPath = await getSavePath();
    await File(path.join(_downloadPath, '.test')).writeAsString('');

    _router.get('/request', _handleRequest);
    _router.post('/upload', _handleUpload);
    _server = await io.serve(_router.call, InternetAddress.anyIPv4, kTcpPort);
  }

  Future<Response> _handleRequest(Request request) async {
    final clientAddress = _getClientAddress(request);
    final accepted = await onRequest(clientAddress);

    if (!accepted) {
      _senderIp = '';
      return Response.forbidden('Transfer not accepted');
    }

    _senderIp = clientAddress;
    return Response.ok('Request accepted');
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

    _speedometer.reset();
    _speedometer.fileSize = totalFileSize;
    _senderIp = '';
    onDownloadStart.call();

    if (request.formData() case var form?) {
      await for (final data in form.formData) {
        if (data.name == 'files') {
          final fileName = data.filename ?? 'file';
          final destinationFile = File('$_downloadPath/$fileName');
          final sink = destinationFile.openWrite();
          _fileNameSubject.add(fileName);
          await for (final chunk in data.part) {
            sink.add(chunk);
            _speedometer.count(chunk.length);
          }
          await sink.flush();
          await sink.close();
        }
      }
    }

    _speedometer.stop();
    onDownloadFinish();

    return Response.ok('File uploaded');
  }

  void close() {
    _server?.close();
    _server = null;
    _senderIp = '';
    _speedometer.reset();
  }
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
