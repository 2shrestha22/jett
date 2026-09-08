import 'package:dart_mappable/dart_mappable.dart';

part 'transfer_status.mapper.dart';

/// Why a transfer ended without delivering its files.
///
/// Travels on the control channel, so values are serialised by name and must
/// not be renamed without bumping [kProtocolVersion].
@MappableEnum()
enum TransferFailure {
  /// The person on the receiving device declined the request.
  declined,

  /// The receiver is already busy with another transfer.
  busy,

  /// The peer could not be reached at all.
  peerUnreachable,

  /// The peer stopped responding partway through.
  timeout,

  /// A file queued for sending could not be read.
  fileUnreadable,

  /// Received data could not be written to disk.
  storageError,

  /// The peer speaks a different version of the control protocol.
  versionMismatch,

  /// The sender could not prove it holds the key it claimed.
  unverifiedSender,

  unknown,
}

enum CancelledBy { sender, receiver }

/// The state of the one transfer a device can be part of at a time.
///
/// Every state past [TransferIdle] carries the id of the attempt it belongs
/// to, so a late result from an abandoned attempt can be dropped.
sealed class TransferState {
  const TransferState();

  /// The attempt this state belongs to, or null when nothing is in flight.
  String? get sessionId;
}

/// Nothing in flight. A new transfer may be started.
final class TransferIdle extends TransferState {
  const TransferIdle();

  @override
  String? get sessionId => null;
}

/// The request has been sent or received; waiting on the receiver's decision.
final class TransferWaiting extends TransferState {
  @override
  final String sessionId;
  final String peerAddress;

  const TransferWaiting({required this.sessionId, required this.peerAddress});
}

/// Files are moving. Re-emitted whenever [fileName] changes.
final class TransferInProgress extends TransferState {
  @override
  final String sessionId;
  final String peerAddress;

  /// The file currently being sent or received, if one has started.
  final String? fileName;

  const TransferInProgress({
    required this.sessionId,
    required this.peerAddress,
    this.fileName,
  });

  TransferInProgress withFile(String name) => TransferInProgress(
    sessionId: sessionId,
    peerAddress: peerAddress,
    fileName: name,
  );
}

final class TransferCompleted extends TransferState {
  @override
  final String sessionId;

  const TransferCompleted({required this.sessionId});
}

final class TransferFailed extends TransferState {
  @override
  final String sessionId;
  final TransferFailure reason;

  const TransferFailed({required this.sessionId, required this.reason});
}

final class TransferCancelled extends TransferState {
  @override
  final String sessionId;
  final CancelledBy by;

  const TransferCancelled({required this.sessionId, required this.by});
}

extension TransferStateX on TransferState {
  /// True once the transfer has stopped for any reason.
  bool get isTerminal => switch (this) {
    TransferCompleted() || TransferFailed() || TransferCancelled() => true,
    TransferIdle() || TransferWaiting() || TransferInProgress() => false,
  };
}
