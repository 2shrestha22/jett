import 'package:equatable/equatable.dart';

class Device extends Equatable {
  final String ipAddress;
  final int port;
  final String name;
  final DateTime lastSeen;

  const Device({
    required this.ipAddress,
    required this.port,
    required this.name,
    required this.lastSeen,
  });

  @override
  String toString() {
    return 'Device(ipAddress: $ipAddress, port: $port, name: $name)';
  }

  @override
  List<Object> get props => [ipAddress];
}
