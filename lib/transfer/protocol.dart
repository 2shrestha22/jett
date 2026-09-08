import 'package:dart_mappable/dart_mappable.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/transfer_status.dart';

part 'protocol.mapper.dart';

/// What a sender signs to prove which device it is.
///
/// Naming the receiver stops a signature collected by one device being replayed
/// at another; naming the session stops it being reused against the same device
/// twice.
String attestationStatement(String sessionId, String receiverFingerprint) =>
    'jett-auth-v1:$sessionId:$receiverFingerprint';

/// The bulk-data path two builds can both speak: the lower of what each of
/// them offers.
///
/// [offered] is what the sender said it can do, defaulting to 1 when the field
/// is missing because the sender predates it. Taking the lower means a new
/// build never asks an old one for an endpoint it does not serve, and an old
/// build is never told about a version it would not understand.
int negotiatedDataPlaneVersion(int offered) =>
    offered < kDataPlaneVersion ? offered : kDataPlaneVersion;

/// A file the sender is offering, described before any bytes move so the
/// receiver can show what it is agreeing to.
@MappableClass()
class OfferedFile with OfferedFileMappable {
  final String name;
  final int size;
  final String? mimeType;

  const OfferedFile({required this.name, required this.size, this.mimeType});
}

/// A frame on the control channel. Every frame names the session it belongs
/// to, so a peer can tell a live exchange from the tail of an abandoned one.
@MappableClass(discriminatorKey: 'type')
sealed class ControlMessage with ControlMessageMappable {
  final String sessionId;

  const ControlMessage({required this.sessionId});

  static final fromJson = ControlMessageMapper.fromJson;
}

/// Sender opens the exchange. Carries everything the receiver needs to decide.
@MappableClass(discriminatorValue: 'request')
class RequestFrame extends ControlMessage with RequestFrameMappable {
  final int protocolVersion;
  final String senderName;
  final List<OfferedFile> files;
  final int totalSize;

  /// The sender does not know this device's key yet and is showing the
  /// verification words, so this device should show its own for comparison.
  ///
  /// Only a request to display something. The words themselves are never
  /// sent: each side derives them from the certificate it holds or was shown,
  /// so a party in the middle cannot make both screens agree.
  final bool requestVerification;

  /// The highest bulk-data version this sender can use. See
  /// [kDataPlaneVersion].
  ///
  /// Defaults to 1, so that a frame from a build predating this field decodes
  /// below [kDataPlaneVersion] and is refused. That is the honest answer: such
  /// a build speaks only the multipart path, and this one no longer has it.
  /// Senders that can do better say so explicitly.
  final int dataPlaneVersion;

  /// The sender's certificate, and its signature over this session and the
  /// receiver's fingerprint.
  ///
  /// Dart will not present a client certificate during a TLS handshake, so
  /// without these the receiver would have no idea who was sending. The
  /// certificate alone proves nothing — it is public — which is why the
  /// signature travels with it.
  final String senderCertificate;
  final String signature;

  const RequestFrame({
    required super.sessionId,
    required this.senderName,
    required this.files,
    required this.totalSize,
    required this.senderCertificate,
    required this.signature,
    this.requestVerification = false,
    this.protocolVersion = kProtocolVersion,
    this.dataPlaneVersion = 1,
  });
}

/// Receiver approved. Only now may the sender upload, and only for this id.
@MappableClass(discriminatorValue: 'accepted')
class AcceptedFrame extends ControlMessage with AcceptedFrameMappable {
  /// Which bulk-data path the receiver settled on: the lower of what the two
  /// builds support. The sender uploads the way this says, not the way it
  /// would have preferred.
  ///
  /// Defaults to 1 for the same reason as [RequestFrame.dataPlaneVersion]: an
  /// acceptance from a build that predates the field lands below
  /// [kDataPlaneVersion], and the sender gives up rather than PUTting blobs
  /// at a receiver with no route for them.
  final int dataPlaneVersion;

  /// The port the receiver's native data plane is listening on, if it has one.
  ///
  /// Null means send the files over the control server's own port, the way
  /// Dart does. The native path speaks the same wire format, so this is only
  /// ever a question of which port and which implementation answers — a
  /// receiver whose native library did not load simply omits it.
  ///
  /// A port rather than a flag because the native server binds one of its own
  /// instead of sharing [kTcpPort], which keeps it clear of the control socket
  /// and of whatever else is already on the device.
  final int? dataPort;

  const AcceptedFrame({
    required super.sessionId,
    this.dataPlaneVersion = 1,
    this.dataPort,
  });
}

/// Receiver refused, with the reason the sender should show.
@MappableClass(discriminatorValue: 'declined')
class DeclinedFrame extends ControlMessage with DeclinedFrameMappable {
  final TransferFailure reason;

  const DeclinedFrame({required super.sessionId, required this.reason});
}

/// Bytes actually written to disk. The receiver's count, not the sender's.
@MappableClass(discriminatorValue: 'progress')
class ProgressFrame extends ControlMessage with ProgressFrameMappable {
  final int bytesReceived;
  final String? fileName;

  const ProgressFrame({
    required super.sessionId,
    required this.bytesReceived,
    this.fileName,
  });
}

@MappableClass(discriminatorValue: 'completed')
class CompletedFrame extends ControlMessage with CompletedFrameMappable {
  const CompletedFrame({required super.sessionId});
}

@MappableClass(discriminatorValue: 'failed')
class FailedFrame extends ControlMessage with FailedFrameMappable {
  final TransferFailure reason;

  const FailedFrame({required super.sessionId, required this.reason});
}

/// Either side is giving up. Best-effort only — a dropped socket means the
/// same thing and is what actually gets relied on.
@MappableClass(discriminatorValue: 'cancel')
class CancelFrame extends ControlMessage with CancelFrameMappable {
  const CancelFrame({required super.sessionId});
}
