import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoHelper {
  const DeviceInfoHelper._();

  static late final String deviceName;

  static Future<void> init() async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    deviceName = deviceInfo.data['name'] ?? 'Unknown Device';
  }
}
