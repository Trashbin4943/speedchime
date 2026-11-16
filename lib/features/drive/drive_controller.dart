import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/alert_state_machine.dart';
import '../../core/relay_notification.dart';
import '../../core/speed_filter.dart';
import '../../providers.dart';

class DriveState {
  const DriveState({
    this.alert = const AlertState.idle(),
    this.speedKph,
    this.relayShown = false,
    this.permissionDenied = false,
  });

  final AlertState alert;

  /// Filtered speed; null = "속도 없음" (GPS 없음).
  final double? speedKph;

  /// F-06 알림(Foreground Service)이 떠 있는지. 추적이 꺼져 있어도
  /// "Chime Relay Off" 상태로 남아 있을 수 있다.
  final bool relayShown;
  final bool permissionDenied;

  /// Chime Relay On: 속도 추적 + 경고 동작 중.
  bool get running => alert.phase != AlertPhase.idle;

  /// Chime Relay Off: 알림은 남아 있고 추적만 멈춘 상태.
  bool get paused => relayShown && !running;
  bool get gpsOk => speedKph != null;

  DriveState copyWith({
    AlertState? alert,
    double? Function()? speedKph,
    bool? relayShown,
    bool? permissionDenied,
  }) {
    return DriveState(
      alert: alert ?? this.alert,
      speedKph: speedKph != null ? speedKph() : this.speedKph,
      relayShown: relayShown ?? this.relayShown,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// 위치 서비스 → 속도 필터 → 경고 상태 머신 → 차임 플레이어 파이프라인.
/// UI는 이 상태를 구독만 하므로 화면이 꺼져도 경고 동작은 유지된다.
///
/// 앱 버튼과 알림 버튼(Chime Relay On/Off/종료)이 같은 메서드를 부른다:
///   start()  = Chime Relay On  (알림 띄우고 추적 시작/재개)
///   pause()  = Chime Relay Off (추적·차임 정지, 알림 유지)
///   stop()   = 종료             (추적 정지 + 알림 닫기 → 대기)
class DriveController extends Notifier<DriveState> {
  final SpeedFilter _filter = SpeedFilter();
  StreamSubscription<RawFix>? _sub;
  StreamSubscription<RelayCommand>? _relaySub;
  Timer? _ticker;

  /// 버튼 연타로 start/pause/stop 이 겹치지 않도록 직렬화한다.
  Future<void> _queue = Future.value();

  @override
  DriveState build() {
    _relaySub = ref.read(relayServiceProvider).commands.listen(_onRelayCommand);
    // onDispose 안에서는 ref 를 쓸 수 없으므로 정리 대상을 미리 잡아둔다.
    final chime = ref.read(chimePlayerProvider);
    final wake = ref.read(screenWakeProvider);
    ref.onDispose(() {
      _relaySub?.cancel();
      _sub?.cancel();
      _ticker?.cancel();
      chime.stop();
      wake.disable();
    });
    // 주행 중 기준 속도 변경: 바로 다시 판정하고 알림 문구도 갱신한다.
    // (OVER 진입은 여전히 F-04 의 2초 지속 규칙을 따른다.)
    ref.listen<int>(settingsProvider.select((s) => s.thresholdKph), (
      prev,
      next,
    ) {
      if (prev == next || !state.running) return;
      _evaluate(DateTime.now());
      _serial(() async {
        if (!state.running) return;
        await ref.read(relayServiceProvider).show(on: true, thresholdKph: next);
      });
    });
    return const DriveState();
  }

  Future<void> start() => _serial(_start);
  Future<void> pause() => _serial(_pause);
  Future<void> stop() => _serial(_stop);

  void _onRelayCommand(RelayCommand cmd) {
    switch (cmd) {
      case RelayCommand.on:
        start();
      case RelayCommand.off:
        pause();
      case RelayCommand.exit:
        stop();
    }
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<void> _start() async {
    if (state.running) return;
    final granted = await ref
        .read(permissionServiceProvider)
        .ensureDrivingPermissions();
    if (!granted) {
      state = state.copyWith(permissionDenied: true);
      return;
    }
    final settings = ref.read(settingsProvider);
    // 알림(Foreground Service)을 먼저 띄워야 백그라운드에서도 위치를 받는다.
    await ref
        .read(relayServiceProvider)
        .show(on: true, thresholdKph: settings.thresholdKph);

    final chime = ref.read(chimePlayerProvider);
    await chime.init();
    await chime.setVolume(settings.volume);
    if (settings.keepScreenOn) await ref.read(screenWakeProvider).enable();

    _filter.reset();
    state = DriveState(alert: AlertStateMachine.start(), relayShown: true);
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

  Future<void> _pause() async {
    if (!state.running) return; // 이미 Off 이거나 대기 상태
    await _stopTracking();
    state = DriveState(alert: AlertStateMachine.stop(), relayShown: true);
    await ref
        .read(relayServiceProvider)
        .show(on: false, thresholdKph: ref.read(settingsProvider).thresholdKph);
  }

  Future<void> _stop() async {
    await _stopTracking();
    await ref.read(relayServiceProvider).stop();
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

  Future<void> _stopTracking() async {
    final chime = ref.read(chimePlayerProvider);
    final wake = ref.read(screenWakeProvider);
    _ticker?.cancel();
    _ticker = null;
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
    await chime.stop();
    await wake.disable();
  }
}

final driveControllerProvider = NotifierProvider<DriveController, DriveState>(
  DriveController.new,
);
