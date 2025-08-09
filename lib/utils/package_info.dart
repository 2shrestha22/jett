import 'package:package_info_plus/package_info_plus.dart';

class PackageInfoHelper {
  const PackageInfoHelper._();

  static late final String appName;
  static late final String packageName;
  static late final String version;
  static late final String buildNumber;

  static Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    appName = packageInfo.appName;
    packageName = packageInfo.packageName;
    version = packageInfo.version;
    buildNumber = packageInfo.buildNumber;
  }
}
