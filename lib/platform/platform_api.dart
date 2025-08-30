import '../messages.g.dart';

// Singleton
class PlatformApi {
  PlatformApi._();
  static final PlatformApi _api = PlatformApi._();
  static PlatformApi get instance => _api;

  final _jettApi = JettApi();

  Future<Version> getPlatformVersion() {
    return _jettApi.getPlatformVersion();
  }

  Future<List<PlatformFile>> getInitialFiles() {
    return _jettApi.getInitialFiles();
  }

  Future<List<APKInfo>> getAPKs() {
    return _jettApi.getAPKs();
  }
}
