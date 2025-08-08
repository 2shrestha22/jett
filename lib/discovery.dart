import 'dart:developer';
import 'dart:io';

const int kPort = 53317;
const String kAddress = '224.0.0.167'; // Example multicast address

void startMulticastListener() async {
  final multicastAddress = InternetAddress(kAddress);
  final socket = await RawDatagramSocket.bind(
    InternetAddress.anyIPv4,
    kPort,
    reuseAddress: true,
  );
  socket.joinMulticast(multicastAddress);
  log('Listening on multicast ${multicastAddress.address}:$kPort');

  socket.listen((event) {
    log(event.toString());
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        final message = String.fromCharCodes(datagram.data);
        log(
          'Received message: $message from ${datagram.address.address}:${datagram.port}',
        );
      }
    }
  });
}

void sendUdpMulticast() async {
  final multicastAddress = InternetAddress(kAddress);
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.joinMulticast(multicastAddress);

  final message = 'Hello from AnySend!';
  final data = message.codeUnits;

  socket.send(data, multicastAddress, kPort);
  log('Sent message: $message to ${multicastAddress.address}:$kPort');

  socket.close();
  log('Socket closed');
}
