import 'dart:async';
import 'dart:collection';

import 'package:anysend/discovery/konst.dart';
import 'package:anysend/model/device.dart';
import 'package:flutter/widgets.dart';

class PresenceNotifier extends ChangeNotifier {
  PresenceNotifier() {
    _timer = Timer.periodic(cleanUpInterval, (timer) {
      if (_activeDevices.isEmpty) return;

      bool mutated = false;
      _activeDevices.removeWhere((device) {
        final duration = DateTime.now().difference(
          _lastSeenHashMap[device.ipAddress]!,
        );
        mutated = duration > deviceTimeout;
        return mutated;
      });
      if (mutated) notifyListeners();
    });
  }

  final Set<Device> _activeDevices = {};
  List<Device> get devices => _activeDevices.toList();
  final _lastSeenHashMap = HashMap<String, DateTime>(); // <IP, LastSeen>

  late Timer _timer;

  void update(Device device, bool available) {
    bool mutated = false;
    // update the last seen time
    if (!available) {
      mutated = _activeDevices.remove(device);
      _lastSeenHashMap.remove(device.ipAddress);
    } else {
      mutated = _activeDevices.add(device);
      _lastSeenHashMap[device.ipAddress] = DateTime.now();
    }
    if (mutated) notifyListeners();
  }

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
