import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/transfer_status.dart';
import 'package:jett/transfer/speedometer.dart';
import 'package:jett/utils/save_path.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path/path.dart' as path;

const disableFileWrite = kDebugMode;

final server = Server();

class Server {
  final _router = Router();
  HttpServer? _server;

  late String _downloadPath;

  final _speedometer = Speedometer();
  ValueStream<SpeedometerReading?> get speedometerReadingStream =>
      _speedometer.readingStream;

  final _fileNameSubject = BehaviorSubject<String>();
  Stream<String> get fileNameStream => _fileNameSubject.stream.distinct();

  final _transferStateSubject = BehaviorSubject<TransferState>.seeded(
    TransferState.idle,
  );
  ValueStream<TransferState> get transferState => _transferStateSubject;

  String senderIp = '';
  // when this is true receiving file will be cancelled and reponse is
  // sent to client
  bool _shouldCancel = true;

  Future<void> start() async {
    _downloadPath = await getSavePath();

    _router
      ..get('/request', _handleRequest)
      ..post('/upload', _handleUpload);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);

    _server = await io.serve(handler, InternetAddress.anyIPv4, kTcpPort);
  }

  late Completer<bool> _requestCompleter;
  void acceptRequest() => _requestCompleter.complete(true);
  void rejectRequest() => _requestCompleter.complete(false);

  Future<Response> _handleRequest(Request request) async {
    if (senderIp.isNotEmpty) {
      return Response.forbidden('Another transfer is in progress');
    }

    _transferStateSubject.add(TransferState.waiting);
    senderIp = _getClientAddress(request);
    _requestCompleter = Completer<bool>();
    final accepted = await _requestCompleter.future;

    if (!accepted) {
      senderIp = '';
      return Response.forbidden('Transfer not accepted');
    }

    _shouldCancel = false;
    return Response.ok('Request accepted');
  }

  Future<Response> _handleUpload(Request request) async {
    if (_getClientAddress(request) != senderIp) {
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
    senderIp = '';
    _transferStateSubject.add(TransferState.inProgress);

    try {
      if (request.formData() case var form?) {
        await for (final data in form.formData) {
          if (data.name == 'files') {
            final fileName = data.filename ?? 'file';
            final destinationFile = File(path.join(_downloadPath, fileName));
            final sink = destinationFile.openWrite();
            _fileNameSubject.add(fileName);
            await for (final chunk in data.part.timeout(
              Duration(seconds: 10),
            )) {
              if (_shouldCancel) {
                return Response.badRequest(body: 'Cancelled by user');
              }

              if (!disableFileWrite) sink.add(chunk);
              _speedometer.count(chunk.length);
            }
            await sink.flush();
            await sink.close();
          }
        }
      }
    } on TimeoutException catch (_) {
      _transferStateSubject.add(TransferState.failed);

      _speedometer.stop();
      return Response.badRequest();
    }

    _speedometer.stop();
    _transferStateSubject.add(TransferState.completed);

    return Response.ok('File uploaded');
  }

  /// Cancel receiving files
  // void requestCancel() {
  //   _shouldCancel = true;
  // }

  /// Reset speedometer readings and session
  void reset() {
    senderIp = '';
    _shouldCancel = true;
    _speedometer.reset();
  }

  /// Closes server and it can't be used without starting it again.
  void close() {
    _server?.close();
    _server = null;
    senderIp = '';
    _shouldCancel = false;
    _speedometer.reset();
  }
}

String _getClientAddress(Request request) {
  return (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
      .remoteAddress
      .address;
}
