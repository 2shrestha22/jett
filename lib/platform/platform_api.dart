import 'dart:async';
import 'dart:io';

import 'package:jett/model/resource.dart';

import '../messages.g.dart' as pigeon;

// Singleton
class PlatformApi {
  PlatformApi._();

  static final PlatformApi _api = PlatformApi._();
  static PlatformApi get instance => _api;

  final _hostApi = pigeon.JettHostApi();

  void init() {
    // precaching
    _getAPKs();
  }

  /// Mobile only API
  Future<pigeon.Version> getPlatformVersion() {
    return _hostApi.getPlatformVersion();
  }

  Future<List<ContentResource>> getInitialFiles() async {
    final files = await _hostApi.getInitialFiles();

    return files.map((e) => ContentResource(name: e.name, uri: e.uri)).toList();
  }

  Stream<List<ContentResource>> files() {
    return pigeon.files().map(
      (event) => (event).map((e) {
        if (e is! pigeon.PlatformFile) {
          throw Exception(
            'Invalid type received from platform: ${e.runtimeType}',
          );
        }
        return ContentResource(uri: e.uri, name: e.name);
      }).toList(),
    );
  }

  late Completer<List<pigeon.APKInfo>> _apkCompleter;
  Future<List<pigeon.APKInfo>> get apkList => _apkCompleter.future;
  void _getAPKs() {
    if (!Platform.isAndroid) return;

    _apkCompleter = Completer<List<pigeon.APKInfo>>();
    _hostApi
        .getAPKs(withSystemApp: true)
        .then(
          (value) => _apkCompleter.complete(value),
          onError: (e) => _apkCompleter.completeError(e),
        );
  }
}
