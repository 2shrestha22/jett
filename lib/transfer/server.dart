import 'dart:async';
import 'dart:io';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/transfer/speedometer.dart';
import 'package:anysend/utils/save_path.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
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
  final VoidCallback onError;

  Server({
    required this.onRequest,
    required this.onDownloadStart,
    required this.onDownloadFinish,
    required this.onError,
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

  String _clientIp = '';
  // when this is true receiving file will be cancelled and reponse is
  // sent to client
  bool _shouldCancel = true;

  Future<void> start() async {
    _downloadPath = await getSavePath();

    _router
      ..get('/request', _handleRequest)
      ..post('/upload', _handleUpload);

    _server = await io.serve(_router.call, InternetAddress.anyIPv4, kTcpPort);
  }

  Future<Response> _handleRequest(Request request) async {
    final clientAddress = _getClientAddress(request);
    final accepted = await onRequest(clientAddress);

    if (!accepted) {
      _clientIp = '';
      return Response.forbidden('Transfer not accepted');
    }

    _shouldCancel = false;
    _clientIp = clientAddress;
    return Response.ok('Request accepted');
  }

  Future<Response> _handleUpload(Request request) async {
    if (_getClientAddress(request) != _clientIp) {
      return Response.forbidden('Transfer not accepted from this IP');
    }

    final fileSizeHeader = request.headers['x-file-size'];
    int totalFileSize = int.parse(fileSizeHeader!);

    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.startsWith('multipart/form-data')) {
      return Response(400, body: 'Unsupported content type');
    }

    _speedometer.reset();
    _speedometer.fileSize = totalFileSize;
    // clear as soon as receiving starts to avoid duplicate request
    _clientIp = '';
    onDownloadStart.call();

    try {
      if (request.formData() case var form?) {
        await for (final data in form.formData) {
          if (data.name == 'files') {
            final fileName = data.filename ?? 'file';
            // final destinationFile = File('$_downloadPath/$fileName');
            // final sink = destinationFile.openWrite();
            _fileNameSubject.add(fileName);
            await for (final chunk in data.part.timeout(
              Duration(seconds: 10),
            )) {
              if (_shouldCancel) {
                return Response.badRequest(body: 'Cancelled by user');
              }
              // sink.add(chunk);
              _speedometer.count(chunk.length);
            }
            // await sink.flush();
            // await sink.close();
          }
        }
      }
    } on TimeoutException catch (_) {
      onError();
      _speedometer.stop();
      return Response.badRequest();
    }

    _speedometer.stop();
    onDownloadFinish();

    return Response.ok('File uploaded');
  }

  /// Cancel receiving files
  // void requestCancel() {
  //   _shouldCancel = true;
  // }

  /// Reset speedometer readings and session
  void reset() {
    _clientIp = '';
    _shouldCancel = true;
    _speedometer.reset();
  }

  /// Closes server and it can't be used without starting it again.
  void close() {
    _server?.close();
    _server = null;
    _clientIp = '';
    _shouldCancel = false;
    _speedometer.reset();
  }
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
