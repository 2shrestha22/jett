import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:anysend/model/message.dart';
import 'package:anysend/utils/device_info.dart';

import 'konst.dart';

typedef OnMessageCallback =
    void Function(Message message, String ipAddress, int port);

class PresenceBroadcaster {
  final _multicastAddress = InternetAddress(kAddress);

  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> init() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.joinMulticast(_multicastAddress);
  }

  Future<void> startPresenceAnnounce() async {
    final message = Message(name: DeviceInfoHelper.deviceName);
    final data = message.toJson().codeUnits;

    _timer = Timer.periodic(pingInterval, (timer) async {
      _socket?.send(data, _multicastAddress, kUdpPort);
      log('Sent Presense: $message to ${_multicastAddress.address}:$kUdpPort');
    });
  }

  Future<void> stopPresenceAnnounce() async {
    _timer?.cancel();
    _timer = null;
  }

  void close() {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

class PresenceListener {
  final _multicastAddress = InternetAddress(kAddress);

  RawDatagramSocket? _socket;

  Future<void> listenMessage(OnMessageCallback onMessage) async {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kUdpPort,
      reuseAddress: true,
    );
    _socket?.joinMulticast(_multicastAddress);

    _socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          final message = Message.fromJson(String.fromCharCodes(datagram.data));
          onMessage(message, datagram.address.address, datagram.port);
        }
      }
    });
  }

  void close() {
    _socket?.close();
    _socket = null;
  }
}
