import 'dart:collection';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:rxdart/streams.dart';
import 'package:rxdart/subjects.dart';
part 'speedometer.mapper.dart';

@MappableClass()
class SpeedometerReading with SpeedometerReadingMappable {
  final int totalBytesTransferred;
  final int elapsedMilliseconds;
  final int? fileSize;
  final double speedBps;

  SpeedometerReading({
    required this.totalBytesTransferred,
    required this.elapsedMilliseconds,
    required this.fileSize,
    required this.speedBps,
  });

  double get avgSpeedBps =>
      totalBytesTransferred /
      (elapsedMilliseconds / 1000).clamp(1, double.infinity);

  /// Returns the progress as a fraction between 0.0 and 1.0.
  /// If fileSize is null, returns 0.0.
  double get progress => fileSize != null && fileSize! > 0
      ? totalBytesTransferred / fileSize!
      : 0.0;
}

class Speedometer {
  /// Rolling window used for the reported speed.
  static const _rollingWindowMs = 3000;

  /// Readings are published no more often than this. [count] runs per chunk,
  /// hundreds of times a second, but nothing consumes readings at that rate.
  static const _publishIntervalMs = 100;

  int? fileSize;

  final _stopwatch = Stopwatch();
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  final _reading = BehaviorSubject<SpeedometerReading?>.seeded(null);
  ValueStream<SpeedometerReading?> get readingStream => _reading;

  /// Chunks inside the rolling window, oldest first. A queue because they leave
  /// from the front.
  final Queue<_ChunkData> _window = ListQueue<_ChunkData>();

  /// Bytes held in [_window], carried along rather than recomputed. Summing on
  /// each chunk made the cost of counting grow with the transfer speed.
  int _windowBytes = 0;

  int _totalBytes = 0;
  int _lastPublishedMs = -_publishIntervalMs;

  /// Records [bytes] as having moved, and publishes a reading if one is due.
  void count(int bytes) {
    if (!_stopwatch.isRunning) _stopwatch.start();
    final now = _stopwatch.elapsedMilliseconds;

    _window.addLast(_ChunkData(size: bytes, timestamp: now));
    _windowBytes += bytes;
    _totalBytes += bytes;

    final cutoff = now - _rollingWindowMs;
    while (_window.isNotEmpty && _window.first.timestamp < cutoff) {
      _windowBytes -= _window.removeFirst().size;
    }

    if (now - _lastPublishedMs >= _publishIntervalMs) {
      _lastPublishedMs = now;
      _publish(now, _currentSpeedBps());
    }
  }

  double _currentSpeedBps() {
    if (_window.isEmpty) return 0;
    final span = _window.last.timestamp - _window.first.timestamp;
    // clamped away from zero: a single chunk spans no time at all
    return _windowBytes / (span.clamp(1, _rollingWindowMs) / 1000);
  }

  void _publish(int elapsedMs, double speedBps) {
    _reading.add(
      SpeedometerReading(
        totalBytesTransferred: _totalBytes,
        elapsedMilliseconds: elapsedMs,
        fileSize: fileSize,
        speedBps: speedBps,
      ),
    );
  }

  /// Stops counting and publishes a final reading, ignoring the throttle so the
  /// totals read afterwards include the last chunks.
  void stop() {
    if (_stopwatch.isRunning) _stopwatch.stop();
    if (_totalBytes == 0) return;
    _publish(_stopwatch.elapsedMilliseconds, 0);
  }

  /// Clears readings and the session.
  void reset() {
    fileSize = null;
    _stopwatch.reset();
    _window.clear();
    _windowBytes = 0;
    _totalBytes = 0;
    _lastPublishedMs = -_publishIntervalMs;
    _reading.add(null);
  }
}

class _ChunkData {
  final int size; // bytes
  final int timestamp; // ms since upload start
  _ChunkData({required this.size, required this.timestamp});
}
