import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:network_info_plus/network_info_plus.dart';

final _info = NetworkInfo();

ValueNotifier<String?> useLocalAddress() {
  final result = useState<String?>(null);
  _info.getWifiIP().then((value) {
    result.value = value;
  });

  return result;
}
