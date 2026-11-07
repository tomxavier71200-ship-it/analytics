import 'package:openstrap_analytics/onehz.dart';
import 'package:test/test.dart';

// Synthetic regression, not independently labelled sleep. Small transverse
// motion breaks the gravity-delta detector while the sustained arm-angle
// opportunity and low HR remain continuous.
({List<AccelSample> accel, List<double> hr}) recording({
  bool gapActive = false,
  bool gapMissing = false,
  bool gapCardiacMissing = false,
  double gapHr = 62,
  int startHour = 22,
  int sleepEndHour = 11,
}) {
  final base = DateTime.utc(2026, 1, 10, startHour - 1).millisecondsSinceEpoch;
  final accel = <AccelSample>[];
  final hr = <double>[];
  for (var s = 0; s < (sleepEndHour + 1) * 3600; s++) {
    final gap = s >= 6 * 3600 && s < 8 * 3600;
    final active = s < 3600 || s >= sleepEndHour * 3600 || (gap && gapActive);
    final x = active ? (s.isEven ? 0.0 : 0.4) : (gap && s.isEven ? 0.02 : 0.0);
    final z = active ? (s.isEven ? 1.0 : 0.5) : 1.0;
    accel.add(
        AccelSample(base + s * 1000.0, x, 0, z, valid: !(gap && gapMissing)));
    hr.add(active ? 95 : (gap ? (gapCardiacMissing ? 0 : gapHr) : 60));
  }
  return (accel: accel, hr: hr);
}

void main() {
  SleepSegmentation run({
    bool active = false,
    bool missing = false,
    bool cardiacMissing = false,
    double gapHr = 62,
    int startHour = 22,
  }) {
    final data = recording(
        gapActive: active,
        gapMissing: missing,
        gapCardiacMissing: cardiacMissing,
        gapHr: gapHr,
        startHour: startHour);
    return segmentSleep(data.accel, data.hr, tzOffsetSec: 0);
  }

  double wakeHour(SleepSegmentation result) {
    final wake = DateTime.fromMillisecondsSinceEpoch(
        result.window!.offsetMs!.round(),
        isUtc: true);
    return wake.hour + wake.minute / 60;
  }

  test('continuous overnight opportunity retains a long noisy continuation',
      () {
    final result = run();
    expect(result.present, isTrue);
    expect(wakeHour(result), closeTo(8, 0.25));
    expect(result.inBedSec, greaterThan(9 * 3600));
    expect(result.tstSec! + result.wakeSec! + result.unobservedSec!,
        result.inBedSec);
  });

  test('sustained activity separates the two sleep periods', () {
    expect(wakeHour(run(active: true)), closeTo(3, 0.25));
  });

  test('stillness with elevated HR does not extend the night', () {
    expect(wakeHour(run(gapHr: 90)), closeTo(3, 0.25));
  });

  test('missing gravity cannot establish an overnight opportunity', () {
    expect(wakeHour(run(missing: true)), closeTo(3, 0.25));
  });

  test('missing cardiac evidence cannot bridge the long interruption', () {
    expect(wakeHour(run(cardiacMissing: true)), closeTo(3, 0.25));
  });

  test('daytime candidates are not joined by the overnight exception', () {
    final result = run(startHour: 9);
    expect(result.inBedSec ?? 0, lessThan(6 * 3600));
  });

  test('a manual window remains authoritative', () {
    final data = recording();
    final start = data.accel.first.tsMs ~/ 1000;
    final result = segmentSleep(data.accel, data.hr,
        tzOffsetSec: 0,
        forcedWindow: (onsetSec: start + 3600, offsetSec: start + 6 * 3600));
    expect(result.window!.onsetMs, (start + 3600) * 1000.0);
    expect(result.window!.offsetMs, (start + 6 * 3600) * 1000.0);
  });

  test('long-gap reconciliation cannot exceed the existing 16-hour cap', () {
    final data = recording(sleepEndHour: 19);
    final result = segmentSleep(data.accel, data.hr, tzOffsetSec: 0);
    expect(result.present, isTrue);
    expect(result.inBedSec, lessThanOrEqualTo(16 * 3600));
  });

  test('overnight checks use the supplied timezone', () {
    // The identical UTC recording is 09:00-19:00 at UTC+11; it must not gain
    // an overnight continuation from interpreting UTC hours as local hours.
    final data = recording();
    final result = segmentSleep(data.accel, data.hr, tzOffsetSec: 11 * 3600);
    expect(result.inBedSec ?? 0, lessThan(6 * 3600));
  });
}
