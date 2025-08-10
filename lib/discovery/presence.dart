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
  final _baseMessage = Message(name: DeviceInfoHelper.deviceName);

  RawDatagramSocket? _socket;
  Timer? _timer;

  Future<void> init() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket?.joinMulticast(_multicastAddress);
  }

  Future<void> startPresenceAnnounce() async {
    final data = _baseMessage.toJson().codeUnits;
    // announce as soon as this method is called
    _socket?.send(data, _multicastAddress, kUdpPort);
    // then in periodic time
    _timer = Timer.periodic(pingInterval, (timer) async {
      _socket?.send(data, _multicastAddress, kUdpPort);
      log(
        'Sent Presense: $_baseMessage to ${_multicastAddress.address}:$kUdpPort',
      );
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
