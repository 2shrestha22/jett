import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:anysend/model/message.dart';
import 'package:anysend/utils/device_info.dart';

import 'konst.dart';

typedef OnMessageCallback =
    void Function(Message message, String ipAddress, int port);

class Receiver {
  final multicastAddress = InternetAddress(kAddress);
  RawDatagramSocket? socket;
  Timer? _timer;

  Future<void> init() async {
    socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket?.joinMulticast(multicastAddress);
  }

  Future<void> announcePresense() async {
    final message = Message(name: DeviceInfoHelper.deviceName);
    final data = message.toJson().codeUnits;

    _timer = Timer.periodic(pingInterval, (timer) async {
      socket?.send(data, multicastAddress, kUdpPort);
      log('Sent Presense: $message to ${multicastAddress.address}:$kUdpPort');
    });
  }

  void close() {
    _timer?.cancel();
    socket?.close();
  }
}

class Sender {
  final multicastAddress = InternetAddress(kAddress);
  RawDatagramSocket? socket;

  Future<void> listenMessage(OnMessageCallback onMessage) async {
    socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kUdpPort,
      reuseAddress: true,
    );
    socket?.joinMulticast(multicastAddress);
    log('Listening on multicast ${multicastAddress.address}:$kUdpPort');

    socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket?.receive();
        if (datagram != null) {
          final message = Message.fromJson(String.fromCharCodes(datagram.data));
          onMessage(message, datagram.address.address, datagram.port);
        }
      }
    });
  }

  void close() {
    socket?.close();
    log('Multicast listener socket closed');
  }
}
