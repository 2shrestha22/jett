import 'dart:async';

import 'package:jett/discovery/konst.dart';
import 'package:jett/model/device.dart';
import 'package:flutter/widgets.dart';

class PresenceNotifier extends ChangeNotifier {
  PresenceNotifier() {
    _timer = Timer.periodic(cleanUpInterval, (timer) {
      if (_devices.isEmpty) return;

      final now = DateTime.now();
      final expired = [
        for (final entry in _devices.entries)
          if (now.difference(entry.value.lastSeen) > deviceTimeout) entry.key,
      ];

      if (expired.isEmpty) return;
      expired.forEach(_devices.remove);
      notifyListeners();
    });
  }

  /// Keyed by [Device.id] so a peer that restarts, or moves to a new address,
  /// replaces its previous entry instead of appearing twice. Insertion order
  /// gives the list a stable order.
  final _devices = <String, _Entry>{};

  late final Timer _timer;

  List<Device> get devices => [for (final e in _devices.values) e.device];

  void update(Device device, bool available) {
    if (!available) {
      if (_devices.remove(device.id) != null) notifyListeners();
      return;
    }

    final previous = _devices[device.id];
    _devices[device.id] = _Entry(device, DateTime.now());
    if (previous == null || previous.device != device) notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  String toString() {
    return 'ActiveDevices(devices: ${devices.map((d) => d.toString()).join(', ')})';
  }
}

class _Entry {
  final Device device;
  final DateTime lastSeen;

  const _Entry(this.device, this.lastSeen);
}
