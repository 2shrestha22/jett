import 'package:dart_mappable/dart_mappable.dart';
import 'package:jett/discovery/konst.dart';
import 'package:jett/model/transfer_status.dart';

part 'protocol.mapper.dart';

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

  const RequestFrame({
    required super.sessionId,
    required this.senderName,
    required this.files,
    required this.totalSize,
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
