import 'package:dart_mappable/dart_mappable.dart';
import 'package:jett/discovery/konst.dart';

part 'device.mapper.dart';

@MappableClass()
class Device with DeviceMappable {
  final String ipAddress;
  final String name;

  /// Null for a device running a build that predates the control channel.
  final int? protocolVersion;

  const Device({
    required this.ipAddress,
    required this.name,
    this.protocolVersion,
  });

  /// False when this device speaks a protocol we cannot transfer over, which
  /// means it needs updating before it can be sent to.
  bool get isSupported => protocolVersion == kProtocolVersion;

  @override
  String toString() {
    return 'Device(ipAddress: $ipAddress, name: $name, '
        'protocolVersion: $protocolVersion)';
  }
}
