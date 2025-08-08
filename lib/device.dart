import 'dart:async';
import 'dart:developer';

import 'package:anysend/discovery/konst.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

class Device extends Equatable {
  final String ipAddress;
  final int port;
  final String name;
  final DateTime lastSeen;

  const Device({
    required this.ipAddress,
    required this.port,
    required this.name,
    required this.lastSeen,
  });

  @override
  String toString() {
    return 'Device(ipAddress: $ipAddress, port: $port, name: $name)';
  }

  @override
  List<Object> get props => [ipAddress];
}

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
