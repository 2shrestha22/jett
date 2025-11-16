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

  final Completer _ready = .new();
  Future<void> init() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.joinMulticast(_multicastAddress);
    // listen for the first write event to mark socket as ready
    _socket?.listen((event) {
      if (!_ready.isCompleted && event == RawSocketEvent.write) {
        _ready.complete();
      }
    });
  }

  Future<void> startPresenceAnnounce() async {
    await _ready.future;

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
    stopPresenceAnnounce();
    _socket?.close();
    _socket = null;
  }
}
