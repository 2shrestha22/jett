import 'package:network_info_plus/network_info_plus.dart';

final _info = NetworkInfo();

Future<String> getLocalIp() async {
  final wifiIP = await _info.getWifiIP();

  return wifiIP ?? '';
}
