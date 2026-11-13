/// PRD 6. 경고 상태 머신. 차임 재생 여부는 이 상태 머신만 결정한다.
///
/// 대기(idle) ──주행 시작──▶ NORMAL ──기준 이상 2초 지속──▶ OVER
///     ▲                       ▲                              │
///     └──────주행 종료─────────┴── 기준−5kph 미만 / 속도 없음 ◀┘
enum AlertPhase { idle, normal, over }

class AlertConfig {
  const AlertConfig({
    required this.thresholdKph,
    this.enterDelay = const Duration(seconds: 2),
    this.hysteresisKph = 5,
  });

  final int thresholdKph;
  final Duration enterDelay;
  final int hysteresisKph;

  double get exitBelowKph => (thresholdKph - hysteresisKph).toDouble();
}

/// Immutable machine state. [aboveSince] tracks how long speed has been at
/// or above the threshold while still NORMAL.
class AlertState {
  const AlertState._(this.phase, this.aboveSince);

  const AlertState.idle() : this._(AlertPhase.idle, null);
  const AlertState.normal([DateTime? aboveSince])
    : this._(AlertPhase.normal, aboveSince);
  const AlertState.over() : this._(AlertPhase.over, null);

  final AlertPhase phase;
  final DateTime? aboveSince;

  bool get chimeOn => phase == AlertPhase.over;

  @override
  bool operator ==(Object other) =>
      other is AlertState &&
      other.phase == phase &&
      other.aboveSince == aboveSince;

  @override
  int get hashCode => Object.hash(phase, aboveSince);

  @override
  String toString() => 'AlertState($phase, aboveSince: $aboveSince)';
}

/// Pure transition functions: (state, input, time) → state.
abstract final class AlertStateMachine {
  static AlertState start() => const AlertState.normal();

  static AlertState stop() => const AlertState.idle();

  /// Evaluate one tick. [speedKph] is the filtered speed, or null for
  /// "속도 없음".
  static AlertState step(
    AlertState state, {
    required double? speedKph,
    required DateTime now,
    required AlertConfig config,
  }) {
    switch (state.phase) {
      case AlertPhase.idle:
        return state;

      case AlertPhase.normal:
        if (speedKph == null || speedKph < config.thresholdKph) {
          return const AlertState.normal();
        }
        final since = state.aboveSince ?? now;
        if (now.difference(since) >= config.enterDelay) {
          return const AlertState.over();
        }
        return AlertState.normal(since);

      case AlertPhase.over:
        if (speedKph == null || speedKph < config.exitBelowKph) {
          return const AlertState.normal();
        }
        return state;
    }
  }
}
