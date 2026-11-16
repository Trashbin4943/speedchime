import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/gait.dart';

void main() {
  test('속도 없음·0 이하는 정지', () {
    expect(Gait.forSpeed(null).moving, isFalse);
    expect(Gait.forSpeed(0).tier, GaitTier.stop);
    expect(Gait.forSpeed(-3).tier, GaitTier.stop);
  });

  test('단계 경계: 40/80/120', () {
    expect(Gait.forSpeed(39.9).tier, GaitTier.walk);
    expect(Gait.forSpeed(40).tier, GaitTier.trot);
    expect(Gait.forSpeed(80).tier, GaitTier.canter);
    expect(Gait.forSpeed(120).tier, GaitTier.gallop);
  });

  test('stride = 1.6 × 40 / (v + 40), 빠를수록 짧아짐', () {
    expect(Gait.forSpeed(40).strideSeconds, closeTo(0.8, 1e-9));
    expect(Gait.forSpeed(120).strideSeconds, closeTo(0.4, 1e-9));
    var prev = double.infinity;
    for (var v = 1.0; v <= 200; v += 7) {
      final s = Gait.forSpeed(v).strideSeconds;
      expect(s, lessThan(prev));
      prev = s;
    }
  });

  test('포즈: 다리 각도 범위, 앞다리 짝은 엇갈림', () {
    for (var p = 0.0; p < 4; p += 0.05) {
      final pose = HorsePose.at(p);
      for (final a in [pose.frontA, pose.frontB, pose.hindA, pose.hindB]) {
        expect(a, inInclusiveRange(-34, 30));
      }
      expect(pose.roadOffset, inInclusiveRange(0, 36));
    }
    final p0 = HorsePose.at(0);
    expect(p0.frontA, closeTo(30, 1e-9));
    expect(p0.hindA, closeTo(-34, 1e-9)); // 앞·뒤는 반대 위상
  });

  test('포즈는 위상에 연속 (속도가 바뀌어도 튀지 않음)', () {
    final a = HorsePose.at(0.999);
    final b = HorsePose.at(1.001);
    expect((a.frontA - b.frontA).abs(), lessThan(0.5));
  });

  test('정지 자세는 다리가 곧고 움직임 없음', () {
    const p = HorsePose.standing;
    expect([p.frontA, p.frontB, p.hindA, p.hindB, p.bodyY], everyElement(0));
  });
}
