import 'dart:io';

import 'package:mime/mime.dart';
import 'package:uri_content/uri_content.dart';
import 'package:path/path.dart' as path;

// uri_content library supports all platforms so ContentResource can be
// technically used everywhere and we may not need FileResource
sealed class Resource {
  const Resource();

  String get name;

  /// Identifier (file path, content:// uri, etc.)
  String get identifier;

  /// Open stream of bytes
  Stream<List<int>> openRead();

  /// Get content length, if known
  Future<int?> length();

  String? get mimeType => lookupMimeType(name);
}

class FileResource extends Resource {
  final File _file;

  FileResource(String path) : _file = File(path);

  @override
  String get name => path.basename(_file.path);

  @override
  String get identifier => _file.path;

  @override
  Stream<List<int>> openRead() => _file.openRead();

  @override
  Future<int?> length() async {
    final exist = await _file.exists();
    if (exist) {
      final length = await _file.length();
      return length;
    }
    return null;
  }
}

class ContentResource extends Resource {
  final Uri _uri;
  final String _name;

  ContentResource({required String uri, String? name})
    : _uri = _ensureFileUri(uri),
      _name = name ?? path.basename(uri);

  final _uriContent = UriContent();

  @override
  String get name => _name;

  @override
  String get identifier => _uri.toString();

  @override
  Stream<List<int>> openRead() => _uriContent.getContentStream(
    _uri,
    bufferSize: 1024 * 256, // using 256 KB, default was too big
  );

  @override
  Future<int?> length() => _uriContent.getContentLength(_uri);
}

// uri_content does not work without scheme so need to append it manually
Uri _ensureFileUri(String path) {
  if (path.startsWith('/')) {
    // Absolute local path → prepend file://
    return Uri.parse('file://$path');
  } else {
    // Already a URI scheme or relative path → parse as-is
    return Uri.parse(path);
  }
}
