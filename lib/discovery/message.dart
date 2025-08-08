class Message {
  final String ipAddress;
  final int port;
  final String name;

  Message({required this.ipAddress, required this.port, required this.name});

  @override
  String toString() {
    return 'Message(ipAddress: $ipAddress, port: $port, name: $name)';
  }
}

enum DeviceType { sender, receiver }
