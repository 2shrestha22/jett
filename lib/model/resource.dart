import 'dart:developer';
import 'dart:io';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:jett/platform/platform_api.dart';
import 'package:mime/mime.dart';
import 'package:uri_content/uri_content.dart';
import 'package:path/path.dart' as path;

/// How the native data plane can take hold of a resource's bytes.
///
/// Each subclass answers for itself; [Resource.identifier] cannot be inspected
/// for this, since a `content://` URI has no path, a `file://` URI has one that
/// does not look like it, and a Windows path starts with no slash.
sealed class NativeSource {
  const NativeSource();
}

/// A path the native side opens for itself. Nothing to release.
class NativePath extends NativeSource {
  final String path;

  const NativePath(this.path);
}

/// An already-open descriptor, for a source with no usable path.
///
/// **Ownership passes to whoever receives this.** Handing it to the data plane
/// transfers that duty; otherwise the holder must call
/// `DataPlane.closeDescriptor`.
class NativeFd extends NativeSource {
  final int fd;

  const NativeFd(this.fd);
}

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

  /// Release any OS-level access held for this resource. Called when the
  /// resource is removed from the send list.
  Future<void> release() async {}

  /// How the native data plane can send this resource, or null if the bytes
  /// have to be read through Dart.
  ///
  /// Called once per transfer, immediately before the send starts. A [NativeFd]
  /// returned here is the caller's to close.
  Future<NativeSource?> nativeSource() async => null;
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

  @override
  Future<NativeSource?> nativeSource() async => NativePath(_file.path);
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

  /// A `file:` URI is a path wearing a scheme; anything else on Android is a
  /// provider handle only the framework can open.
  ///
  /// Files dropped onto the desktop window arrive as absolute paths and become
  /// `file://` URIs via [_ensureFileUri], so they take the first case.
  @override
  Future<NativeSource?> nativeSource() async {
    if (_uri.isScheme('file')) return NativePath(_uri.toFilePath());
    if (!Platform.isAndroid) return null;

    try {
      return NativeFd(
        await PlatformApi.instance.openFileDescriptor(identifier),
      );
    } catch (e) {
      // Not a failure yet; the Dart reader takes a different route through the
      // same provider, and fails there with a better error.
      log('No descriptor for $_name; it will be read through Dart', error: e);
      return null;
    }
  }
}

/// A file picked on iOS/macOS whose security-scoped access is held open for as
/// long as the resource is in the send list, so it can be read in place rather
/// than copied into the app container. Released via [release].
class ScopedFileResource extends Resource {
  final FastFilePickerPath _pickerPath;
  bool? _hasAccess;

  ScopedFileResource(this._pickerPath, this._hasAccess);

  File get _file => File(_pickerPath.path!);

  @override
  String get name => _pickerPath.name;

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

  @override
  Future<void> release() async {
    await _pickerPath.releaseAppleScopedResource(_hasAccess);
    _hasAccess = null;
  }

  /// A real path, readable in place until [release] is called.
  @override
  Future<NativeSource?> nativeSource() async => NativePath(_file.path);
}

/// A drive letter is indistinguishable from a URI scheme, so `C:\dir\f.bin`
/// parses as scheme `c`. Windows paths must be recognised before [Uri.parse].
final _windowsAbsolutePath = RegExp(r'^[a-zA-Z]:[\\/]');

// uri_content does not work without scheme so need to append it manually
Uri _ensureFileUri(String path) {
  final isWindowsPath = _windowsAbsolutePath.hasMatch(path);
  if (path.startsWith('/') || isWindowsPath) {
    // Absolute local path. `Uri.file` rather than string concatenation because
    // it escapes the path and knows the separator; the convention comes from the
    // shape of the path, so a Windows path reads as one wherever this runs.
    return Uri.file(path, windows: isWindowsPath);
  } else {
    // Already a URI scheme or relative path → parse as-is
    return Uri.parse(path);
  }
}
