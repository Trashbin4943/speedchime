import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/alert_state_machine.dart';
import '../../core/speed_filter.dart';
import '../../providers.dart';

class DriveState {
  const DriveState({
    this.alert = const AlertState.idle(),
    this.speedKph,
    this.permissionDenied = false,
  });

  final AlertState alert;

  /// Filtered speed; null = "속도 없음" (GPS 없음).
  final double? speedKph;
  final bool permissionDenied;

  bool get running => alert.phase != AlertPhase.idle;
  bool get gpsOk => speedKph != null;

  DriveState copyWith({
    AlertState? alert,
    double? Function()? speedKph,
    bool? permissionDenied,
  }) {
    return DriveState(
      alert: alert ?? this.alert,
      speedKph: speedKph != null ? speedKph() : this.speedKph,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// 위치 서비스 → 속도 필터 → 경고 상태 머신 → 차임 플레이어 파이프라인.
/// UI는 이 상태를 구독만 하므로 화면이 꺼져도 경고 동작은 유지된다.
class DriveController extends Notifier<DriveState> {
  final SpeedFilter _filter = SpeedFilter();
  StreamSubscription<RawFix>? _sub;
  Timer? _ticker;

  @override
  DriveState build() {
    ref.onDispose(_teardown);
    return const DriveState();
  }

  Future<void> start() async {
    if (state.running) return;
    final granted = await ref
        .read(permissionServiceProvider)
        .ensureDrivingPermissions();
    if (!granted) {
      state = state.copyWith(permissionDenied: true);
      return;
    }
    final settings = ref.read(settingsProvider);
    final chime = ref.read(chimePlayerProvider);
    await chime.init();
    await chime.setVolume(settings.volume);
    if (settings.keepScreenOn) await WakelockPlus.enable();

    _filter.reset();
    state = DriveState(alert: AlertStateMachine.start());
    _sub = ref.read(locationServiceProvider).fixes().listen((fix) {
      _filter.add(fix);
      _evaluate(DateTime.now());
    });
    // Tick even without fixes so staleness (3s → 속도 없음) is detected.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _evaluate(DateTime.now()),
    );
  }

  Future<void> stop() async {
    _teardown();
    state = DriveState(alert: AlertStateMachine.stop());
  }

  void _evaluate(DateTime now) {
    if (!state.running) return;
    final speed = _filter.current(now);
    final next = AlertStateMachine.step(
      state.alert,
      speedKph: speed,
      now: now,
      config: AlertConfig(
        thresholdKph: ref.read(settingsProvider).thresholdKph,
      ),
    );
    if (next.chimeOn != state.alert.chimeOn) {
      final chime = ref.read(chimePlayerProvider);
      next.chimeOn ? chime.start() : chime.stop();
    }
    state = state.copyWith(alert: next, speedKph: () => speed);
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    _ticker?.cancel();
    _ticker = null;
    ref.read(chimePlayerProvider).stop();
    WakelockPlus.disable();
  }
}

final driveControllerProvider = NotifierProvider<DriveController, DriveState>(
  DriveController.new,
);
