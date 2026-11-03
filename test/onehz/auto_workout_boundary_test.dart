import 'package:openstrap_analytics/onehz.dart';
import 'package:test/test.dart';

void main() {
  ({List<int> ts, List<int> bpm}) trace(List<(int, int)> segments) {
    final ts = <int>[];
    final bpm = <int>[];
    var t = 0;
    for (final (seconds, value) in segments) {
      for (var i = 0; i < seconds; i++) {
        ts.add(t++);
        bpm.add(value);
      }
    }
    return (ts: ts, bpm: bpm);
  }

  group('automatic workout boundaries', () {
    test('ten-minute elevated core qualifies; a shorter core does not', () {
      final tenMinutes = trace(const [
        (300, 60),
        (601, 140),
        (300, 60),
      ]);
      final shorter = trace(const [
        (300, 60),
        (600, 140),
        (300, 60),
      ]);

      expect(
        AutoWorkoutDetector.detect(
          hrTs: tenMinutes.ts,
          hrBpm: tenMinutes.bpm,
          restingBpm: 60,
          maxBpm: 190,
        ),
        hasLength(1),
      );
      expect(
        AutoWorkoutDetector.detect(
          hrTs: shorter.ts,
          hrBpm: shorter.bpm,
          restingBpm: 60,
          maxBpm: 190,
        ),
        isEmpty,
      );
    });

    test('ten-minute window survives a two-minute HR dip', () {
      final d = trace(const [
        (300, 60),
        (300, 140),
        (120, 110),
        (300, 140),
        (300, 60),
      ]);

      final out = AutoWorkoutDetector.detect(
        hrTs: d.ts,
        hrBpm: d.bpm,
        restingBpm: 60,
        maxBpm: 190,
      );

      expect(out, hasLength(1));
      expect(out.single.startSec, 300);
      expect(out.single.endSec, 1019);
    });

    test('qualified core expands through contiguous warm-up and cool-down', () {
      final d = trace(const [
        (300, 60),
        (300, 105),
        (780, 140),
        (240, 105),
        (300, 60),
      ]);

      final out = AutoWorkoutDetector.detect(
        hrTs: d.ts,
        hrBpm: d.bpm,
        restingBpm: 60,
        maxBpm: 190,
      );

      expect(out, hasLength(1));
      expect(out.single.startSec, 300);
      expect(out.single.endSec, 1619);
      expect(out.single.durationMin, 21);
    });

    test('boundary expansion is capped and does not absorb an active day', () {
      final d = trace(const [
        (900, 105),
        (780, 140),
        (900, 105),
      ]);

      final out = AutoWorkoutDetector.detect(
        hrTs: d.ts,
        hrBpm: d.bpm,
        restingBpm: 60,
        maxBpm: 190,
      );

      expect(out, hasLength(1));
      expect(out.single.startSec, 300);
      expect(out.single.endSec, 2279);
    });

    test('a recording gap is never crossed while refining a boundary', () {
      final ts = <int>[];
      final bpm = <int>[];
      for (var t = 0; t < 300; t++) {
        ts.add(t);
        bpm.add(105);
      }
      for (var t = 500; t < 1280; t++) {
        ts.add(t);
        bpm.add(140);
      }

      final out = AutoWorkoutDetector.detect(
        hrTs: ts,
        hrBpm: bpm,
        restingBpm: 60,
        maxBpm: 190,
      );

      expect(out, hasLength(1));
      expect(out.single.startSec, 500);
    });

    test('saved warm-up overlap suppresses the same detected workout', () {
      final d = trace(const [
        (300, 60),
        (300, 105),
        (780, 140),
        (300, 60),
      ]);

      final out = AutoWorkoutDetector.detect(
        hrTs: d.ts,
        hrBpm: d.bpm,
        restingBpm: 60,
        maxBpm: 190,
        savedSpans: const [SavedWorkoutSpan(350, 400)],
      );

      expect(out, isEmpty);
    });

    test('slow HR drift with low motion is still rejected', () {
      final ts = <int>[];
      final bpm = <int>[];
      for (var t = 0; t < 600; t++) {
        ts.add(t);
        bpm.add(60);
      }
      for (var i = 0; i < 600; i++) {
        ts.add(600 + i);
        bpm.add(60 + (i * 80 / 600).round());
      }
      for (var i = 0; i < 900; i++) {
        ts.add(1200 + i);
        bpm.add(140);
      }

      final out = AutoWorkoutDetector.detect(
        hrTs: ts,
        hrBpm: bpm,
        restingBpm: 60,
        maxBpm: 190,
        motion: [for (final t in ts) MotionPoint(t, 0.01)],
      );

      expect(out, isEmpty);
    });

    test('rapid 12 bpm onset admits low-wrist-motion cycling', () {
      final ts = <int>[];
      final bpm = <int>[];
      for (var t = 0; t < 300; t++) {
        ts.add(t);
        bpm.add(108);
      }
      for (var t = 300; t <= 900; t++) {
        ts.add(t);
        bpm.add(126);
      }

      final out = AutoWorkoutDetector.detect(
        hrTs: ts,
        hrBpm: bpm,
        restingBpm: 62,
        maxBpm: 190,
        motion: [for (final t in ts) MotionPoint(t, 0.05)],
      );

      expect(out, hasLength(1));
    });
  });
}
