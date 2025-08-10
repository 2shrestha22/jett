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

      bool mutated = false;
      _activeDevices.removeWhere((device) {
        final duration = DateTime.now().difference(device.lastSeen);
        mutated = duration > deviceTimeout;
        return mutated;
      });
      if (mutated) notifyListeners();
    });
  }

  void add(Device device, bool available) {
    bool mutated = false;
    // update the last seen time
    mutated = _activeDevices.remove(device);
    if (available) {
      mutated |= _activeDevices.add(device);
    }
    if (mutated) notifyListeners();
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
