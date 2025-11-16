import 'dart:async';
import 'dart:io';

import 'package:jett/discovery/konst.dart';
import 'package:jett/model/message.dart';
import 'package:jett/utils/network.dart';

typedef OnMessageCallback =
    void Function(Message message, String address, int port);

class PresenceListener {
  final _multicastAddress = InternetAddress(kAddress);
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;

  late String _localIp;

  Future<void> init() async {
    _localIp = await getLocalIp();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kUdpPort);
    _socket?.joinMulticast(_multicastAddress);
  }

  void startListening(OnMessageCallback onMessage) {
    _subscription = _socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null && datagram.address.address != _localIp) {
          final message = Message.fromJson(String.fromCharCodes(datagram.data));
          onMessage(message, datagram.address.address, datagram.port);
        }
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void close() {
    stopListening();
    _socket?.close();
    _socket = null;
  }
}
