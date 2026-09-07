import 'package:flutter/foundation.dart';

/// How a transfer was carried, kept so it can be read on the device.
///
/// The fallback from the native data plane to Dart is silent, so a speed alone
/// does not say which path a slow transfer took. This records it.
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

/// The last transfer in each direction, for the About screen. Not persisted,
/// not part of the transfer state, and drives nothing.
class TransferDiagnostics {
  TransferDiagnostics._();

  static final TransferDiagnostics instance = TransferDiagnostics._();

  final sent = ValueNotifier<TransferReport?>(null);
  final received = ValueNotifier<TransferReport?>(null);
}
