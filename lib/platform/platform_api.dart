import 'dart:async';
import 'dart:io';

import '../messages.g.dart';

// Singleton
class PlatformApi {
  PlatformApi._();
  static final PlatformApi _api = PlatformApi._();
  static PlatformApi get instance => _api;

  void init() {
    // precaching
    _getAPKs();
  }

  final _jettApi = JettApi();

  Future<Version> getPlatformVersion() {
    return _jettApi.getPlatformVersion();
  }

  Future<List<PlatformFile>> getInitialFiles() {
    return _jettApi.getInitialFiles();
  }

  late Completer<List<APKInfo>> _apkCompleter;
  Future<List<APKInfo>> get apkList => _apkCompleter.future;
  void _getAPKs() {
    if (!Platform.isAndroid) return;

    _apkCompleter = Completer<List<APKInfo>>();
    _jettApi
        .getAPKs(withSystemApp: true)
        .then(
          (value) => _apkCompleter.complete(value),
          onError: (e) => _apkCompleter.completeError(e),
        );
  }
}
