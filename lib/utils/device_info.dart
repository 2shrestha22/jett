import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoHelper {
  const DeviceInfoHelper._();

  static late final String deviceName;
  static late final String model;

  static Future<void> init() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await DeviceInfoPlugin().androidInfo;
        deviceName = info.name;
        model = info.model;
        break;
      case TargetPlatform.iOS:
        final info = await DeviceInfoPlugin().iosInfo;
        deviceName = info.name;
        model = info.model;
        break;
      case TargetPlatform.linux:
        final info = await DeviceInfoPlugin().linuxInfo;
        deviceName = info.prettyName;
        model = ''; // no model for linux / sad
        break;
      case TargetPlatform.macOS:
        final info = await DeviceInfoPlugin().macOsInfo;
        deviceName = info.computerName;
        model = info.model;
        break;
      case TargetPlatform.windows:
        final info = await DeviceInfoPlugin().windowsInfo;
        deviceName = info.computerName;
        model = info.displayVersion;
        break;
      default:
        deviceName = 'Unknown Device';
    }
  }
}
