import 'dart:io';

import 'package:anysend/discovery/konst.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf/shelf_io.dart' as io;

import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

// void main() async {
//   final server = Server();
//   await server.start();
// }

class Server {
  final router = Router();

  late String _downloadPath;

  Future<void> start() async {
    router.post('/upload', _handleUpload);

    await path_provider.getDownloadsDirectory().then((directory) {
      if (directory != null) {
        _downloadPath = directory.path;
      } else {
        throw Exception('Could not get download directory!');
      }
    });

    await io.serve(router.call, '0.0.0.0', kTcpPort);
  }

  Future<Response> _handleUpload(Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.startsWith('multipart/form-data')) {
      return Response(400, body: 'Unsupported content type');
    }

    if (request.formData() case var form?) {
      await for (final data in form.formData) {
        if (data.name == 'files') {
          final destinationFile = File(
            '$_downloadPath/${data.filename ?? 'file'}',
          );
          await data.part.pipe(destinationFile.openWrite());
        }
      }
    }

    return Response.ok('File uploaded');
  }
}
