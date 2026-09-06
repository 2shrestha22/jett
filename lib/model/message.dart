import 'package:dart_mappable/dart_mappable.dart';
import 'package:jett/discovery/konst.dart';

part 'message.mapper.dart';

@MappableClass()
/// Represents a message that can be sent over multicast for device presence.
class Message with MessageMappable {
  final String name;
  final bool available;

  /// Null when the broadcast came from a build that predates the control
  /// channel, which is the only way such a device can be recognised.
  ///
  /// Deliberately has no default: a default would be substituted when the key
  /// is missing, making a v1.0.11 broadcast indistinguishable from ours.
  /// Senders pass [kProtocolVersion] explicitly.
  final int? protocolVersion;

  /// The sender's certificate fingerprint, which identifies the device across
  /// restarts and address changes.
  ///
  /// Unauthenticated: anyone can broadcast any fingerprint, so this is only a
  /// hint for finding and naming devices. Proof of the matching private key
  /// comes from the TLS handshake when a transfer is actually attempted.
  final String? fingerprint;

  Message({
    required this.name,
    this.available = true,
    this.protocolVersion,
    this.fingerprint,
  });

  static final fromMap = MessageMapper.fromMap;
  static final fromJson = MessageMapper.fromJson;
}
