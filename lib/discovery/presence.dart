import 'dart:async';
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
    if (_timer?.isActive ?? false) return;

    final data = _baseMessage.toJson().codeUnits;
    // announce as soon as this method is called
    _socket?.send(data, _multicastAddress, kUdpPort);
    // then in periodic time
    _timer = Timer.periodic(pingInterval, (timer) async {
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

class PresenceListener {
  final _multicastAddress = InternetAddress(kAddress);
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;

  Future<void> init() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kUdpPort);
    _socket?.joinMulticast(_multicastAddress);
  }

  void startListening(OnMessageCallback onMessage) {
    _subscription = _socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
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
