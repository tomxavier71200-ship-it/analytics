import 'package:openstrap_analytics/onehz.dart';
import 'package:test/test.dart';

void main() {
  List<CyclingMinute> recording({
    bool walkingEdges = true,
    bool steady = false,
    bool gap = false,
    int rideSteps = 8,
  }) =>
      [
        for (var i = 0; i < 17; i++)
          if (!(gap && i == 8))
            (
              startSec: i * 60,
              bpm: steady
                  ? 112.0
                  : i < 4
                      ? 94.0
                      : (i == 4 ? 103.0 : 112.0),
              peak: 116,
              steps: i < 4 || i >= 14 ? (walkingEdges ? 70 : 0) : rideSteps,
              motion: i < 4 || i >= 14 ? .3 : .08,
            ),
      ];

  List<DetectedWorkout> run(List<CyclingMinute> minutes) =>
      suggestEasyCycling(minutes, restingBpm: 57, maxBpm: 190);

  test('suggests the easy ten-minute ride with the surrounding walks excluded',
      () {
    final ride = run(recording()).single;
    expect((ride.startSec, ride.endSec), (4 * 60, 14 * 60));
    expect(ride.sport, 'cycling');
  });

  test('abstains without corroborating gait, HR rise or coverage', () {
    expect(run(recording(walkingEdges: false)), isEmpty);
    expect(run(recording(steady: true)), isEmpty);
    expect(run(recording(gap: true)), isEmpty);
    expect(run(recording(rideSteps: 90)), isEmpty);
  });

  test('ten minutes is a minimum and a longer ride keeps its full window', () {
    final values = recording();
    final longer = [
      ...values.take(14),
      for (var i = 14; i < 22; i++)
        (startSec: i * 60, bpm: 112.0, peak: 116, steps: 8, motion: .08),
      for (final m in values.skip(14))
        (
          startSec: m.startSec + 8 * 60,
          bpm: m.bpm,
          peak: m.peak,
          steps: m.steps,
          motion: m.motion
        ),
    ];
    final ride = run(longer).single;
    expect((ride.startSec, ride.endSec), (4 * 60, 22 * 60));
    expect(ride.durationMin, 18);
  });
}
