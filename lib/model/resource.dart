import 'dart:developer';
import 'dart:io';

import 'package:fast_file_picker/fast_file_picker.dart';
import 'package:jett/platform/platform_api.dart';
import 'package:mime/mime.dart';
import 'package:uri_content/uri_content.dart';
import 'package:path/path.dart' as path;

// uri_content library supports all platforms so ContentResource can be
// technically used everywhere and we may not need FileResource
/// How the native data plane can take hold of a resource's bytes.
///
/// The question "can Rust send this itself?" belongs to the resource, not to
/// the transfer code. Deciding it by looking at [Resource.identifier] — testing
/// whether the string starts with a slash, say — gets three cases wrong: a
/// `content://` URI has no path at all, a `file://` URI has one but does not
/// look like it, and a Windows path never starts with a slash to begin with.
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
/// **Ownership passes to whoever receives this.** The descriptor is detached
/// from the platform object that produced it, so nothing will close it unless
/// the receiver does. Handing it to the data plane transfers that duty; if it
/// is never handed over, the holder must close it — `DataPlane.closeDescriptor`
/// is how.
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

  /// How the native data plane can send this resource, or null if it cannot
  /// and the bytes have to be read through Dart.
  ///
  /// Called once per transfer, immediately before the send starts. A
  /// [NativeFd] returned here is opened at that moment and is the caller's to
  /// close.
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
  /// provider handle that only the framework can open.
  ///
  /// The first case matters more than it looks. Files dropped onto the desktop
  /// window arrive here as absolute paths and are turned into `file://` URIs by
  /// [_ensureFileUri], so without this they would read as unopenable and send
  /// through Dart despite sitting on a local disk.
  @override
  Future<NativeSource?> nativeSource() async {
    if (_uri.isScheme('file')) return NativePath(_uri.toFilePath());
    if (!Platform.isAndroid) return null;

    try {
      return NativeFd(
        await PlatformApi.instance.openFileDescriptor(identifier),
      );
    } catch (e) {
      // A provider that will not open it is not a failure yet: the Dart reader
      // goes through the same provider by a different route and may still
      // manage, and if it cannot the transfer fails there with a better error.
      log('No descriptor for $_name; it will be read through Dart', error: e);
      return null;
    }
  }
}

/// A file picked on iOS/macOS whose security-scoped access is held open
/// for as long as the resource is in the send list. This lets the file be
/// read in place at transfer time, without copying it into the app
/// container. Access is released via [release].
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

  /// A real path, readable in place for as long as [release] has not been
  /// called — which is what the scoped access is holding open.
  @override
  Future<NativeSource?> nativeSource() async => NativePath(_file.path);
}

/// A drive letter is indistinguishable from a URI scheme, so `C:\dir\f.bin`
/// parses as scheme `c` with path `\dir\f.bin` — a URI that names nothing.
/// Windows paths therefore have to be recognised before [Uri.parse] sees them.
final _windowsAbsolutePath = RegExp(r'^[a-zA-Z]:[\\/]');

// uri_content does not work without scheme so need to append it manually
Uri _ensureFileUri(String path) {
  final isWindowsPath = _windowsAbsolutePath.hasMatch(path);
  if (path.startsWith('/') || isWindowsPath) {
    // Absolute local path → a real file: URI. `Uri.file` rather than string
    // concatenation because it escapes the path and knows the separator;
    // `file://$path` leaves a space unescaped and makes nonsense of a
    // backslash. The convention is chosen by the shape of the path rather than
    // by the host, so that a Windows path is read as one wherever this runs.
    return Uri.file(path, windows: isWindowsPath);
  } else {
    // Already a URI scheme or relative path → parse as-is
    return Uri.parse(path);
  }
}
