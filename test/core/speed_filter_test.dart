import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/speed_filter.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int s) => t0.add(Duration(seconds: s));

  RawFix fix(
    int s, {
    double? mps,
    double? speedAcc = 0.5,
    double hAcc = 5,
    double lat = 37.0,
    double lon = 127.0,
  }) => RawFix(
    timestamp: at(s),
    latitude: lat,
    longitude: lon,
    horizontalAccuracyM: hAcc,
    speedMps: mps,
    speedAccuracyMps: speedAcc,
  );

  test('F-01: converts Doppler m/s to kph', () {
    final f = SpeedFilter();
    expect(f.add(fix(0, mps: 100 / 3.6)), closeTo(100, 1e-9));
  });

  test('F-02: EMA smooths toward new value', () {
    final f = SpeedFilter(); // alpha = 0.4
    f.add(fix(0, mps: 100 / 3.6));
    expect(f.add(fix(1, mps: 120 / 3.6)), closeTo(108, 1e-9));
  });

  test('F-02: rejects low-accuracy samples', () {
    final f = SpeedFilter();
    f.add(fix(0, mps: 100 / 3.6));
    expect(f.add(fix(1, mps: 200 / 3.6, hAcc: 80)), closeTo(100, 1e-9));
    expect(f.add(fix(2, mps: 200 / 3.6, speedAcc: 5)), closeTo(100, 1e-9));
  });

  test('F-02: no accepted sample for >3s → null (속도 없음)', () {
    final f = SpeedFilter();
    f.add(fix(0, mps: 30));
    expect(f.current(at(3)), isNotNull);
    expect(f.current(at(4)), isNull);
  });

  test('F-01: falls back to distance/time only when Doppler missing', () {
    final f = SpeedFilter();
    f.add(fix(0, mps: null, lat: 37.0));
    // ~0.001° lat ≈ 111 m in 1 s ≈ 400 kph → implausible, rejected
    expect(f.add(fix(1, mps: null, lat: 37.001)), isNull);
    // ~0.0003° lat ≈ 33.4 m in 1 s ≈ 120 kph
    final g = SpeedFilter();
    g.add(fix(0, mps: -1, lat: 37.0));
    expect(g.add(fix(1, mps: -1, lat: 37.0003)), closeTo(120, 1.0));
  });
}
