import 'package:dart_mappable/dart_mappable.dart';
import 'package:jett/discovery/konst.dart';

part 'device.mapper.dart';

@MappableClass()
class Device with DeviceMappable {
  final String ipAddress;
  final String name;

  /// Null for a device running a build that predates the control channel.
  final int? protocolVersion;

  /// The device's certificate fingerprint, absent on older builds.
  ///
  /// Only a claim until a TLS handshake proves possession of the matching
  /// private key; good enough to tell devices apart, not to trust them.
  final String? fingerprint;

  const Device({
    required this.ipAddress,
    required this.name,
    this.protocolVersion,
    this.fingerprint,
  });

  /// Stable key for deduplication. The fingerprint survives restarts and
  /// address changes; the address is only a fallback for builds that publish
  /// no fingerprint.
  String get id => fingerprint ?? ipAddress;

  /// False when this device speaks a protocol we cannot transfer over, which
  /// means it needs updating before it can be sent to.
  bool get isSupported => protocolVersion == kProtocolVersion;

  @override
  String toString() {
    return 'Device(ipAddress: $ipAddress, name: $name, '
        'protocolVersion: $protocolVersion, fingerprint: $fingerprint)';
  }
}
