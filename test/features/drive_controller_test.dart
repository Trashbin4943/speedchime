import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/alert_state_machine.dart';
import 'package:speedchime/core/app_settings.dart';
import 'package:speedchime/core/chime_sound.dart';
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
  final used = <ChimeSound>[];

  @override
  ChimeSound alertSound = ChimeCatalog.defaultSound;
  @override
  Future<bool> useSound(ChimeSound sound) async {
    used.add(sound);
    alertSound = sound;
    return true;
  }

  @override
  Future<Duration?> probe(String filePath) async => const Duration(seconds: 1);

  @override
  Future<void> init() async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<bool> preview([ChimeSound? sound]) async => true;
  @override
  Future<void> stopPreview() async {}
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

  // 저장소 없이 메모리에서만 바꾼다.
  @override
  Future<void> update(AppSettings next) async => state = next;
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
        chimeCatalogProvider.overrideWithValue(
          AsyncValue.data(
            ChimeCatalog.fromAssets([
              'assets/audio/chime.wav',
              'assets/audio/chime_beep.wav',
            ]),
          ),
        ),
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

  RawFix fixAt(double kph) => RawFix(
    timestamp: DateTime.now(),
    latitude: 37,
    longitude: 127,
    horizontalAccuracyM: 5,
    speedMps: kph / 3.6,
    speedAccuracyMps: 0.5,
  );

  test('주행 중 기준 속도 변경 → 알림 문구 갱신', () async {
    await ctl().start();
    await c.read(settingsProvider.notifier).setThreshold(140);
    await pumpEventQueue();
    expect(relay.log, ['on:120', 'on:140']);
    expect(st().running, isTrue);
  });

  test('주행 중 기준을 현재 속도 아래로 내리면 바로 초과 판정 시작', () async {
    await ctl().start();
    location.ctrl!.add(fixAt(110));
    await pumpEventQueue();
    expect(st().alert.aboveSince, isNull); // 110 < 120

    await c.read(settingsProvider.notifier).setThreshold(100);
    await pumpEventQueue();
    expect(st().alert.phase, AlertPhase.normal);
    expect(st().alert.aboveSince, isNotNull); // 2초 지속 타이머 시작
  });

  test('OVER 중 기준을 올리면 바로 NORMAL, 차임 정지', () async {
    await ctl().start();
    location.ctrl!.add(fixAt(130));
    await pumpEventQueue();
    // 2초 지속을 기다리는 대신 상태를 OVER 로 맞춰 둔다.
    c.read(driveControllerProvider.notifier).state = st().copyWith(
      alert: const AlertState.over(),
    );
    chime.playing = true;

    await c.read(settingsProvider.notifier).setThreshold(140);
    await pumpEventQueue();
    expect(st().alert.phase, AlertPhase.normal);
    expect(chime.playing, isFalse);
  });

  test('대기 중 기준 변경은 알림을 띄우지 않음', () async {
    await c.read(settingsProvider.notifier).setThreshold(100);
    await pumpEventQueue();
    expect(relay.log, isEmpty);
  });

  test('주행 시작 시 고른 경고음을 건다', () async {
    await c
        .read(settingsProvider.notifier)
        .setSound(
          const AssetChimeSound('assets/audio/chime_beep.wav', '디지털 삐삐'),
        );
    await ctl().start();
    expect(chime.used.single.label, '디지털 삐삐');
  });

  test('내 사운드 파일 정보가 없으면 기본음으로 시작', () async {
    await c
        .read(settingsProvider.notifier)
        .update(const AppSettings(soundId: CustomChimeSound.customId));
    await ctl().start();
    expect(chime.used.single, ChimeCatalog.defaultSound);
  });

  test('내 사운드 삭제 시 선택이 기본음으로 돌아감', () async {
    final n = c.read(settingsProvider.notifier);
    await n.setCustomSound(const CustomChimeSound('/x/custom_1.mp3', 'a.mp3'));
    expect(c.read(selectedSoundProvider), isA<CustomChimeSound>());
    await n.clearCustomSound();
    expect(c.read(settingsProvider).customSoundPath, isNull);
    expect(c.read(selectedSoundProvider), ChimeCatalog.defaultSound);
  });
}
