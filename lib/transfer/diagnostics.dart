import 'package:flutter/foundation.dart';

/// How a transfer was carried, kept so it can be read on the device.
///
/// The fallback from the native data plane to Dart is deliberately silent — a
/// device whose native library is missing should still transfer. That silence
/// makes it impossible to tell, from a speed alone, whether a slow transfer was
/// slow because the native path was not used or because something else is the
/// limit. This records which it was.
enum Transport {
  /// Bytes went through the Rust data plane.
  native('Native (Rust)'),

  /// Bytes went through the Dart handlers.
  dart('Dart');

  const Transport(this.label);
  final String label;
}

@immutable
class TransferReport {
  final Transport transport;

  /// Why Dart carried it, when the native path was available but not used.
  /// Null when there was nothing to explain.
  final String? fellBackBecause;

  final int bytes;
  final Duration elapsed;

  const TransferReport({
    required this.transport,
    required this.bytes,
    required this.elapsed,
    this.fellBackBecause,
  });

  double get megabytesPerSecond {
    final seconds = elapsed.inMilliseconds / 1000;
    if (seconds <= 0) return 0;
    return bytes / (1024 * 1024) / seconds;
  }

  String get summary {
    final rate = megabytesPerSecond.toStringAsFixed(1);
    final size = (bytes / (1024 * 1024)).toStringAsFixed(0);
    return '${transport.label} · $rate MB/s · $size MB';
  }
}

/// The last transfer in each direction, for the About screen.
///
/// Deliberately not persisted and not part of the transfer state: this is here
/// to answer "which path did that actually take" while testing on a device, not
/// to drive anything.
class TransferDiagnostics {
  TransferDiagnostics._();

  static final TransferDiagnostics instance = TransferDiagnostics._();

  final sent = ValueNotifier<TransferReport?>(null);
  final received = ValueNotifier<TransferReport?>(null);

  void recordSent(TransferReport report) => sent.value = report;
  void recordReceived(TransferReport report) => received.value = report;
}
