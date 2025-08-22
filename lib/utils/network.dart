import 'package:network_info_plus/network_info_plus.dart';

final _info = NetworkInfo();

Future<String> getLocalIp() async {
  final wifiIP = await _info.getWifiIP();

  return wifiIP ?? '';
}

(String, String) splitAddress(String addr) {
  final parts = addr.split('.');
  final networkIdentifier = '${parts.take(parts.length - 1).join('.')}.';
  final hostIdentifier = parts.last;

  return (networkIdentifier, hostIdentifier);
}
