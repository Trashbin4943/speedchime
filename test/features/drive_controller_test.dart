import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/alert_state_machine.dart';
import 'package:speedchime/core/app_settings.dart';
import 'package:speedchime/core/relay_notification.dart';
import 'package:speedchime/core/speed_filter.dart';
import 'package:speedchime/features/drive/drive_controller.dart';
import 'package:speedchime/providers.dart';
import 'package:speedchime/services/chime_player.dart';
import 'package:speedchime/services/location_service.dart';
import 'package:speedchime/services/permission_service.dart';
import 'package:speedchime/services/relay_service.dart';
import 'package:speedchime/services/screen_wake.dart';

class FakeRelay implements RelayService {
  final ctrl = StreamController<RelayCommand>.broadcast();
  final log = <String>[];
  bool shown = false;

  @override
  Stream<RelayCommand> get commands => ctrl.stream;

  @override
  Future<bool> get isRunning async => shown;

  @override
  Future<void> show({required bool on, required int thresholdKph}) async {
    log.add(on ? 'on:$thresholdKph' : 'off');
    shown = true;
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    shown = false;
  }
}

class FakeLocation implements LocationService {
  StreamController<RawFix>? ctrl;
  int listens = 0;

  @override
  Stream<RawFix> fixes() {
    listens++;
    ctrl = StreamController<RawFix>();
    return ctrl!.stream;
  }
}

class FakePermission implements PermissionService {
  bool granted = true;

  @override
  Future<bool> ensureDrivingPermissions() async => granted;

  @override
  Future<bool> openSettings() async => true;
}

class FakeChime implements ChimePlayer {
  bool playing = false;

  @override
  Future<void> init() async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> preview() async {}
  @override
  Future<void> dispose() async {}
}

class FakeWake implements ScreenWake {
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
}

class FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  late FakeRelay relay;
  late FakeLocation location;
  late FakePermission permission;
  late FakeChime chime;
  late ProviderContainer c;

  setUp(() {
    relay = FakeRelay();
    location = FakeLocation();
    permission = FakePermission();
    chime = FakeChime();
    c = ProviderContainer(
      overrides: [
        relayServiceProvider.overrideWithValue(relay),
        locationServiceProvider.overrideWithValue(location),
        permissionServiceProvider.overrideWithValue(permission),
        chimePlayerProvider.overrideWithValue(chime),
        screenWakeProvider.overrideWithValue(FakeWake()),
        settingsProvider.overrideWith(FakeSettings.new),
      ],
    );
  });

  tearDown(() => c.dispose());

  DriveController ctl() => c.read(driveControllerProvider.notifier);
  DriveState st() => c.read(driveControllerProvider);

  test('주행 시작 → Chime Relay On 알림 + 추적', () async {
    await ctl().start();
    expect(relay.log, ['on:120']);
    expect(st().running, isTrue);
    expect(st().relayShown, isTrue);
    expect(location.listens, 1);
  });

  test('알림 Off → 추적·차임 정지, 알림은 Off 로 유지', () async {
    await ctl().start();
    chime.playing = true; // OVER 중이었다고 가정
    relay.ctrl.add(RelayCommand.off);
    await pumpEventQueue();

    expect(relay.log, ['on:120', 'off']);
    expect(st().alert.phase, AlertPhase.idle);
    expect(st().paused, isTrue);
    expect(chime.playing, isFalse);
    expect(location.ctrl!.hasListener, isFalse);
  });

  test('알림 On → 추적 재개', () async {
    await ctl().start();
    relay.ctrl.add(RelayCommand.off);
    await pumpEventQueue();
    relay.ctrl.add(RelayCommand.on);
    await pumpEventQueue();

    expect(relay.log, ['on:120', 'off', 'on:120']);
    expect(st().running, isTrue);
    expect(location.listens, 2);
  });

  test('알림 종료 → 서비스 종료, 대기 상태', () async {
    await ctl().start();
    relay.ctrl.add(RelayCommand.off);
    await pumpEventQueue();
    relay.ctrl.add(RelayCommand.exit);
    await pumpEventQueue();

    expect(relay.log.last, 'stop');
    expect(st().relayShown, isFalse);
    expect(st().running, isFalse);
  });

  test('앱 주행 종료 → 추적 중에도 바로 알림까지 닫음', () async {
    await ctl().start();
    await ctl().stop();
    expect(relay.log, ['on:120', 'stop']);
    expect(st().relayShown, isFalse);
  });

  test('위치 권한 거부 → 알림을 띄우지 않음', () async {
    permission.granted = false;
    await ctl().start();
    expect(relay.log, isEmpty);
    expect(st().permissionDenied, isTrue);
  });

  test('Off 를 연타해도 한 번만 처리, 대기 상태에선 Off 무시', () async {
    relay.ctrl.add(RelayCommand.off);
    await pumpEventQueue();
    expect(relay.log, isEmpty);

    await ctl().start();
    relay.ctrl
      ..add(RelayCommand.off)
      ..add(RelayCommand.off);
    await pumpEventQueue();
    expect(relay.log, ['on:120', 'off']);
    expect(st().paused, isTrue);
  });
}
