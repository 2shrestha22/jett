import 'dart:async';
import 'dart:io';

import 'package:jett/discovery/konst.dart';
import 'package:jett/model/message.dart';
import 'package:jett/utils/device_info.dart';

class PresenceBroadcaster {
  final _multicastAddress = InternetAddress(kAddress);
  final _baseMessage = Message(name: DeviceInfoHelper.deviceName);

  RawDatagramSocket? _socket;
  Timer? _timer;
  Timer? _retryTimer;

  bool _isClosed = false;

  Future<void> init() async {
    if (_socket != null) return;
    _isClosed = false;
    _retryTimer?.cancel();

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket?.joinMulticast(_multicastAddress);
    } catch (e) {
      if (!_isClosed) {
        // Retry initialization if it fails (e.g. due to missing permissions)
        _retryTimer = Timer(const Duration(seconds: 2), init);
      }
    }
  }

  Future<void> startPresenceAnnounce() async {
    if (_timer?.isActive ?? false) return;

    final data = _baseMessage.toJson().codeUnits;
    // announce as soon as this method is called
    _socket?.send(data, _multicastAddress, kUdpPort);
    // then in periodic time
    _timer = Timer.periodic(pingInterval, (timer) {
      _socket?.send(data, _multicastAddress, kUdpPort);
    });
  }

  void stopPresenceAnnounce() {
    // send unavilable before stopping announce
    _socket?.send(
      _baseMessage.copyWith(available: false).toJson().codeUnits,
      _multicastAddress,
      kUdpPort,
    );
    _timer?.cancel();
    _timer = null;
  }

  void close() {
    _isClosed = true;
    _retryTimer?.cancel();
    stopPresenceAnnounce();
    _socket?.close();
    _socket = null;
  }
}
