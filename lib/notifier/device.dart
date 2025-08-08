import 'dart:async';
import 'dart:developer';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/device.dart';
import 'package:flutter/widgets.dart';

class ReceiversNotifier extends ChangeNotifier {
  final Set<Device> _activeDevices = {};
  late Timer _timer;

  ReceiversNotifier() {
    _timer = Timer.periodic(cleanUpInterval, (timer) {
      log('ActiveReceivers: Timer tick, removing last device if exists');
      if (_activeDevices.isEmpty) return;

      _activeDevices.removeWhere((device) {
        final duration = DateTime.now().difference(device.lastSeen);
        return duration > deviceTimeout;
      });
      notifyListeners();
    });
  }

  void add(Device device) {
    // update the last seen time
    _activeDevices.removeWhere((d) => d == device);
    _activeDevices.add(device);
    notifyListeners();
  }

  bool get isEmpty => _activeDevices.isEmpty;
  List<Device> get devices => _activeDevices.toList();

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  String toString() {
    return 'ActiveDevices(devices: ${_activeDevices.map((d) => d.toString()).join(', ')})';
  }
}
