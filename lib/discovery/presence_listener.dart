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

  void startListening(
    OnMessageCallback onMessage, {
    // on iOS and macOS it fails to start for the first time because of
    // permission issue so we schedule a timeout to retry
    void Function()? onDiscoveryTimeout,
  }) {
    _onDiscoveryTimeout = onDiscoveryTimeout;
    _startSelfDiscoveryTimer();

    _subscription = _socket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket?.receive();
        if (datagram != null) {
          if (datagram.address.address == _localIp) {
            _stopSelfDiscoveryTimer();
          } else {
            final message = Message.fromJson(
              String.fromCharCodes(datagram.data),
            );
            onMessage(message, datagram.address.address, datagram.port);
          }
        }
      }
    });
  }

  Future<void> stopListening() async {
    _stopSelfDiscoveryTimer();
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> close() async {
    await stopListening();
    _socket?.close();
    _socket = null;
  }

  Timer? _selfDiscoveryTimer;
  void Function()? _onDiscoveryTimeout;

  void _startSelfDiscoveryTimer() {
    _selfDiscoveryTimer?.cancel();
    _selfDiscoveryTimer = Timer(const Duration(seconds: 3), () {
      _onDiscoveryTimeout?.call();
    });
  }

  void _stopSelfDiscoveryTimer() {
    _selfDiscoveryTimer?.cancel();
    _selfDiscoveryTimer = null;
  }
}
