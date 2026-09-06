import 'package:flutter_test/flutter_test.dart';
import 'package:jett/transfer/speedometer.dart';

const mb = 1024 * 1024;

void main() {
  late Speedometer speedometer;

  setUp(() => speedometer = Speedometer()..fileSize = 100 * mb);

  group('counting', () {
    test('keeps a running total of everything counted', () {
      for (var i = 0; i < 50; i++) {
        speedometer.count(mb);
      }
      speedometer.stop();
      expect(speedometer.readingStream.value!.totalBytesTransferred, 50 * mb);
    });

    test('reports progress against the expected size', () {
      for (var i = 0; i < 25; i++) {
        speedometer.count(mb);
      }
      speedometer.stop();
      expect(speedometer.readingStream.value!.progress, closeTo(0.25, 0.001));
    });

    test('reports a speed while bytes are moving', () async {
      speedometer.count(mb);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      speedometer.count(mb);
      expect(speedometer.readingStream.value!.speedBps, greaterThan(0));
    });
  });

  group('publishing', () {
    test('does not emit a reading for every chunk', () async {
      // The cost that mattered was per-chunk work on the hot path: at a few
      // hundred chunks a second, a reading each was allocating objects and
      // rebuilding the progress bar far faster than anything consumed them.
      var emissions = 0;
      final sub = speedometer.readingStream.listen((_) => emissions++);

      for (var i = 0; i < 2000; i++) {
        speedometer.count(64 * 1024);
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions, lessThan(20), reason: 'got $emissions for 2000 chunks');
    });

    test('still publishes the final totals when stopped', () async {
      // Whatever arrived since the last throttled reading has to land, because
      // the finished-transfer figure is read from here.
      for (var i = 0; i < 2000; i++) {
        speedometer.count(64 * 1024);
      }
      speedometer.stop();

      expect(
        speedometer.readingStream.value!.totalBytesTransferred,
        2000 * 64 * 1024,
      );
      expect(speedometer.readingStream.value!.speedBps, 0);
    });

    test('stopping an idle speedometer publishes nothing', () {
      speedometer.stop();
      expect(speedometer.readingStream.value, isNull);
    });
  });

  group('resetting', () {
    test('clears the totals so the next transfer starts from zero', () {
      for (var i = 0; i < 10; i++) {
        speedometer.count(mb);
      }
      speedometer.stop();
      speedometer.reset();

      expect(speedometer.readingStream.value, isNull);

      speedometer.count(mb);
      speedometer.stop();
      expect(speedometer.readingStream.value!.totalBytesTransferred, mb);
    });
  });

  group('cost', () {
    test('counting does not get slower as the window fills', () {
      // The window holds three seconds of chunks, so a faster link puts more
      // in it. Work per chunk must not grow with that, or the cost rises
      // exactly when there is least room for it.
      int timeFor(int chunks) {
        final s = Speedometer();
        final sw = Stopwatch()..start();
        for (var i = 0; i < chunks; i++) {
          s.count(1024);
        }
        return sw.elapsedMicroseconds;
      }

      timeFor(20000); // warm up
      final small = timeFor(20000);
      final large = timeFor(200000);

      // ten times the chunks should cost about ten times as much, not a
      // hundred; allow generous headroom for a noisy machine
      expect(
        large / small,
        lessThan(30),
        reason: '20k took ${small}us, 200k took ${large}us',
      );
    });
  });
}
