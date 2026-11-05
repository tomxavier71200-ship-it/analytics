import 'dart:math' as math;
import 'package:test/test.dart';
import 'package:openstrap_analytics/onehz.dart';

({List<AccelSample> accel, List<double> hr}) capture(String gap) {
  const start = 20 * 3600;
  final accel = <AccelSample>[], hr = <double>[];
  void block(int minutes, String kind) {
    for (var i = 0; i < minutes * 60; i++) {
      final second = start + accel.length;
      final active = kind == 'awake';
      final missing = kind == 'missing';
      final angle = kind == 'restless' ? 0.8 * math.sin(i * 0.1) : 0.001;
      final wave = math.sin(i * 0.5);
      accel.add(AccelSample(
          second * 1000.0,
          active ? 0.35 * wave : math.sin(angle),
          active ? 0.3 : 0,
          active ? 0.9 * (1 - 0.2 * wave) : math.cos(angle),
          valid: !missing));
      hr.add(missing
          ? 0
          : active
              ? 88
              : 58 + math.sin(i / 120.0));
    }
  }

  block(120, 'awake');
  block(90, 'sleep');
  block(30, gap);
  block(150, 'sleep');
  block(60, 'awake');
  return (accel: accel, hr: hr);
}

void main() {
  for (final gap in ['restless', 'awake', 'missing']) {
    test('a split night stages the observed $gap gap instead of assuming wake',
        () {
      final data = capture(gap);
      final auto = segmentSleep(data.accel, data.hr, tzOffsetSec: 0);
      expect(auto.present, isTrue);
      final window = auto.window!;
      final confirmed =
          segmentSleep(data.accel, data.hr, tzOffsetSec: 0, forcedWindow: (
        onsetSec: (window.onsetMs! / 1000).round(),
        offsetSec: (window.offsetMs! / 1000).round()
      ));
      expect(auto.tstSec, confirmed.tstSec,
          reason:
              'the same boundaries and observations must give the same sleep');
      expect(auto.wasoSec, confirmed.wasoSec);
      if (gap == 'awake') {
        expect(auto.wasoSec, greaterThan(20 * 60),
            reason: 'real sustained movement with high HR must remain awake');
      } else if (gap == 'missing') {
        expect(auto.unobservedSec, greaterThan(29 * 60),
            reason: 'missing recordings must never turn into sleep or awake');
      }
    });
  }
}
