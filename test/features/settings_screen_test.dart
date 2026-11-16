import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speedchime/core/app_settings.dart';
import 'package:speedchime/core/chime_sound.dart';
import 'package:speedchime/features/settings/settings_screen.dart';
import 'package:speedchime/providers.dart';
import 'package:speedchime/services/chime_player.dart';
import 'package:speedchime/services/custom_sound_store.dart';
import 'package:speedchime/ui/meter_theme.dart';

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();

  @override
  Future<void> update(AppSettings next) async => state = next;
}

class _Chime implements ChimePlayer {
  final previewed = <ChimeSound>[];

  @override
  ChimeSound alertSound = ChimeCatalog.defaultSound;
  @override
  Future<bool> preview([ChimeSound? sound]) async {
    previewed.add(sound ?? alertSound);
    return true;
  }

  @override
  Future<void> stopPreview() async {}
  @override
  Future<void> setVolume(double v) async {}
  @override
  Future<Duration?> probe(String filePath) async => const Duration(seconds: 2);
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

void main() {
  late Directory tmp;
  late _Chime chime;
  PickedSound? nextPick;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('settings_screen_test');
    chime = _Chime();
    nextPick = null;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_Settings.new),
          chimePlayerProvider.overrideWithValue(chime),
          chimeCatalogProvider.overrideWithValue(
            AsyncValue.data(
              ChimeCatalog.fromAssets([
                'assets/audio/chime.wav',
                'assets/audio/chime_triple.wav',
                'assets/audio/chime_soft.wav',
                'assets/audio/chime_beep.wav',
                'assets/audio/my_horn.mp3',
              ]),
            ),
          ),
          customSoundStoreProvider.overrideWithValue(
            CustomSoundStore(
              probe: chime.probe,
              picker: () async => nextPick,
              baseDir: () async => tmp,
            ),
          ),
        ],
        child: MaterialApp(theme: meterTheme(), home: const SettingsScreen()),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  /// 실제 파일 I/O 가 끝날 때까지 시간을 주며 프레임을 진행한다.
  Future<void> settle(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 50 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  PickedSound file(String name) =>
      PickedSound(name: name, size: 8, readBytes: () async => Uint8List(8));

  testWidgets('기본 제공음 + 폴더에 넣은 파일이 목록에 뜨고, 고르면 저장', (tester) async {
    final c = await pump(tester);
    for (final label in ['기본 띵똥', '트리플 벨', '부드러운 차임', '디지털 삐삐', 'my horn']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('디지털 삐삐'));
    await tester.pump();
    expect(
      c.read(settingsProvider).soundId,
      'asset:assets/audio/chime_beep.wav',
    );
  });

  testWidgets('미리듣기 버튼은 그 줄의 소리를 재생', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('트리플 벨 미리듣기'));
    await tester.pump();
    expect(chime.previewed.single.label, '트리플 벨');
  });

  testWidgets('내 사운드 추가 → 선택되고 미리듣기, 삭제 → 기본음', (tester) async {
    final c = await pump(tester);
    nextPick = file('경적.mp3');
    await tester.tap(find.text('내 사운드 추가'));
    await settle(tester, () => find.text('경적.mp3').evaluate().isNotEmpty);

    expect(find.text('경적.mp3'), findsOneWidget);
    expect(c.read(selectedSoundProvider), isA<CustomChimeSound>());
    expect(chime.previewed.last.label, '경적.mp3');

    await tester.tap(find.text('내 사운드 삭제'));
    await settle(tester, () => find.text('경적.mp3').evaluate().isEmpty);
    expect(find.text('경적.mp3'), findsNothing);
    expect(c.read(selectedSoundProvider), ChimeCatalog.defaultSound);
    expect(find.text('내 사운드 추가'), findsOneWidget);
  });

  testWidgets('지원하지 않는 파일 → 안내 문구, 설정은 그대로', (tester) async {
    final c = await pump(tester);
    nextPick = file('song.flac');
    await tester.tap(find.text('내 사운드 추가'));
    await settle(
      tester,
      () => find.textContaining('지원하지 않는 형식').evaluate().isNotEmpty,
    );
    expect(find.textContaining('지원하지 않는 형식'), findsOneWidget);
    expect(c.read(settingsProvider).customSoundPath, isNull);
  });
}
