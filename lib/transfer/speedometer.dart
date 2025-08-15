import 'package:rxdart/subjects.dart';

class SpeedometerReading {
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
  int? fileSize;

  final _stopwatch = Stopwatch();
  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  final _reading = BehaviorSubject<SpeedometerReading?>.seeded(null);
  Stream<SpeedometerReading?> get readingStream => _reading;
  SpeedometerReading? get reading => _reading.value;

  // Keep last chunks for rolling average
  final List<_ChunkData> _recentChunks = [];

  /// Rolling window in milliseconds for speed calculation.
  /// Increases the window size to smooth out speed fluctuations.
  static const _rollingWindowMs = 3000;

  /// Starts counting transfer rate.
  void count(int bytes) {
    if (!_stopwatch.isRunning) _stopwatch.start();

    _recentChunks.add(
      _ChunkData(size: bytes, timestamp: _stopwatch.elapsedMilliseconds),
    );

    // Remove old chunks outside rolling window
    final cutoff = _stopwatch.elapsedMilliseconds - _rollingWindowMs;
    while (_recentChunks.isNotEmpty && _recentChunks.first.timestamp < cutoff) {
      _recentChunks.removeAt(0);
    }

    // Calculate rolling average speed (bytes/sec)
    final totalBytesRecent = _recentChunks.fold<int>(
      0,
      (sum, chunk) => sum + chunk.size,
    );

    final diference =
        _recentChunks.last.timestamp - _recentChunks.first.timestamp;
    // clamping min value to avoid divide-by-zero errors
    final elapsedRecentMs = diference.clamp(1, _rollingWindowMs);
    final speedBps = totalBytesRecent / (elapsedRecentMs / 1000);

    final totalBytes = (_reading.value?.totalBytesTransferred ?? 0) + bytes;

    _reading.add(
      SpeedometerReading(
        totalBytesTransferred: totalBytes,
        elapsedMilliseconds: _stopwatch.elapsedMilliseconds,
        fileSize: fileSize,
        speedBps: speedBps,
      ),
    );
  }

  void stop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
    }
  }

  void reset() {
    fileSize = null;
    _stopwatch.reset();
    _reading.add(null);
    _recentChunks.clear();
  }
}

class _ChunkData {
  final int size; // bytes
  final int timestamp; // ms since upload start
  _ChunkData({required this.size, required this.timestamp});
}
