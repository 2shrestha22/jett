import 'package:dart_mappable/dart_mappable.dart';
part 'device.mapper.dart';

@MappableClass()
class Device with DeviceMappable {
  final String ipAddress;
  final int port;
  final String name;

  const Device({
    required this.ipAddress,
    required this.port,
    required this.name,
  });

  @override
  String toString() {
    return 'Device(ipAddress: $ipAddress, port: $port, name: $name)';
  }
}
