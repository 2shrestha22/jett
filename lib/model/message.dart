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
  /// No default, which would be substituted for the missing key and make such
  /// a broadcast indistinguishable from ours. Senders pass [kProtocolVersion]
  /// explicitly.
  final int? protocolVersion;

  /// The sender's certificate fingerprint, which identifies the device across
  /// restarts and address changes.
  ///
  /// Unauthenticated, so only a hint for finding and naming devices; the TLS
  /// handshake proves possession of the matching key.
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
