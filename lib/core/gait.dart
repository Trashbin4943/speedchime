/// 주행 화면의 달리는 말(택시미터 콘셉트) 걸음 계산.
///
/// 속도 차등: 빠를수록 다리를 한 번 휘두르는 시간(stride)이 짧아진다.
///   stride = 1.6초 × 40 ÷ (속도 + 40)
/// 단계 이름은 표시용이며, 모션 자체는 단계 없이 연속으로 변한다.
enum GaitTier {
  stop('정지'),
  walk('걷기'),
  trot('속보'),
  canter('구보'),
  gallop('습보');

  const GaitTier(this.label);

  final String label;
}

class Gait {
  const Gait._(this.tier, this.strideSeconds);

  /// [kph] 가 null(속도 없음)이거나 0 이하면 멈춘 말.
  factory Gait.forSpeed(double? kph) {
    final v = (kph == null || kph.isNaN || kph <= 0) ? 0.0 : kph;
    return Gait._(_tierFor(v), baseStrideSeconds * 40 / (v + 40));
  }

  static const double baseStrideSeconds = 1.6;

  final GaitTier tier;

  /// 다리 한 번 휘두르는 시간(초). 정지일 때도 값은 있지만 모션은 멈춘다.
  final double strideSeconds;

  bool get moving => tier != GaitTier.stop;

  static GaitTier _tierFor(double v) {
    if (v <= 0) return GaitTier.stop;
    if (v < 40) return GaitTier.walk;
    if (v < 80) return GaitTier.trot;
    if (v < 120) return GaitTier.canter;
    return GaitTier.gallop;
  }
}

/// 말 그림 한 프레임의 포즈. [phase] 는 stride 단위로 누적된 시간이라
/// 속도가 바뀌어도 모션이 끊기지 않는다(현재 위치에서 빠르기만 바뀜).
class HorsePose {
  const HorsePose._(
    this.frontA,
    this.frontB,
    this.hindA,
    this.hindB,
    this.bodyY,
    this.tail,
    this.roadOffset,
  );

  factory HorsePose.at(double phase) {
    double leg(double offset) => _lerp(30, -34, _wave(phase + offset));
    return HorsePose._(
      leg(0),
      leg(0.3),
      leg(1.0),
      leg(1.3),
      _lerp(-2.5, 2, _wave(phase)),
      _lerp(-8, 10, _wave(phase)),
      // 점선 한 주기(18) × 2 를 stride 2번에 흘려보낸다.
      (phase / 2 % 1) * 36,
    );
  }

  /// 멈춘 말: 네 다리를 곧게 세운 자세.
  static const standing = HorsePose._(0, 0, 0, 0, 0, 0, 0);

  /// 다리 각도(도). 양수 = 앞으로 뻗음.
  final double frontA, frontB, hindA, hindB;

  /// 몸 위아래 흔들림(px, 160×100 그림 기준).
  final double bodyY;

  /// 꼬리 각도(도).
  final double tail;

  /// 바닥 점선이 왼쪽으로 흐른 거리(px).
  final double roadOffset;

  /// 0→1→0 을 stride 2번에 오가는 ease-in-out 왕복 (CSS alternate 와 같음).
  static double _wave(double p) {
    final u = p % 2;
    final tri = u < 1 ? u : 2 - u;
    return tri < 0.5 ? 2 * tri * tri : 1 - 2 * (1 - tri) * (1 - tri);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
