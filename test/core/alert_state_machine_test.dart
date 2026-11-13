import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/alert_state_machine.dart';

void main() {
  const cfg = AlertConfig(thresholdKph: 120);
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  AlertState run(
    List<(double t, double? kph)> ticks, [
    AlertState start = const AlertState.normal(),
  ]) {
    var s = start;
    for (final (t, kph) in ticks) {
      s = AlertStateMachine.step(s, speedKph: kph, now: at(t), config: cfg);
    }
    return s;
  }

  test('idle ignores speed', () {
    expect(
      run([(0, 200), (5, 200)], const AlertState.idle()).phase,
      AlertPhase.idle,
    );
  });

  test('start → NORMAL, stop → idle', () {
    expect(AlertStateMachine.start().phase, AlertPhase.normal);
    expect(AlertStateMachine.stop().phase, AlertPhase.idle);
  });

  test('F-04: enters OVER only after 2s at/above threshold', () {
    expect(run([(0, 120), (1, 121)]).phase, AlertPhase.normal);
    expect(run([(0, 120), (1, 121), (2, 122)]).phase, AlertPhase.over);
  });

  test('dip below threshold resets the 2s timer', () {
    expect(
      run([(0, 125), (1, 119), (2, 125), (3, 125)]).phase,
      AlertPhase.normal,
    );
    expect(
      run([(0, 125), (1, 119), (2, 125), (4, 125)]).phase,
      AlertPhase.over,
    );
  });

  test('hysteresis: stays OVER until below threshold−5', () {
    final over = run([(0, 130), (2, 130)]);
    expect(over.phase, AlertPhase.over);
    expect(run([(3, 116)], over).phase, AlertPhase.over);
    expect(run([(3, 115)], over).phase, AlertPhase.over);
    expect(run([(3, 114.9)], over).phase, AlertPhase.normal);
  });

  test('no speed (null) → NORMAL from OVER, and never enters OVER', () {
    final over = run([(0, 130), (2, 130)]);
    expect(run([(3, null)], over).phase, AlertPhase.normal);
    expect(
      run([(0, 130), (1, null), (2, 130), (3, 130)]).phase,
      AlertPhase.normal,
    );
  });

  test('chimeOn only in OVER', () {
    expect(const AlertState.idle().chimeOn, isFalse);
    expect(const AlertState.normal().chimeOn, isFalse);
    expect(const AlertState.over().chimeOn, isTrue);
  });
}
