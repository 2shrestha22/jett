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
  });
}

/// Receiver approved. Only now may the sender upload, and only for this id.
@MappableClass(discriminatorValue: 'accepted')
class AcceptedFrame extends ControlMessage with AcceptedFrameMappable {
  const AcceptedFrame({required super.sessionId});
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
