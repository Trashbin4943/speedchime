import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_settings.dart';
import 'core/chime_sound.dart';
import 'services/chime_player.dart';
import 'services/custom_sound_store.dart';
import 'services/location_service.dart';
import 'services/permission_service.dart';
import 'services/relay_service.dart';
import 'services/screen_wake.dart';
import 'services/settings_repository.dart';

/// Overridden in main() after SharedPreferences is loaded.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('override in ProviderScope'),
);

final locationServiceProvider = Provider((ref) => LocationService());
final permissionServiceProvider = Provider((ref) => PermissionService());
final relayServiceProvider = Provider((ref) => RelayService());
final screenWakeProvider = Provider((ref) => ScreenWake());

final chimePlayerProvider = Provider((ref) {
  final player = ChimePlayer();
  ref.onDispose(player.dispose);
  return player;
});

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(settingsRepositoryProvider).load();

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }

  Future<void> setThreshold(int kph) =>
      update(state.copyWith(thresholdKph: kph));
  Future<void> setVolume(double v) => update(state.copyWith(volume: v));
  Future<void> setKeepScreenOn(bool on) =>
      update(state.copyWith(keepScreenOn: on));
  Future<void> setTheme(MeterTheme t) => update(state.copyWith(theme: t));
  Future<void> setSound(ChimeSound sound) =>
      update(state.copyWith(soundId: sound.id));

  /// 내 사운드를 새 파일로 바꾸고 선택한다.
  Future<void> setCustomSound(CustomChimeSound sound) => update(
    state.copyWith(
      soundId: sound.id,
      customSoundPath: () => sound.filePath,
      customSoundName: () => sound.fileName,
    ),
  );

  /// 내 사운드를 지운다. 선택돼 있었다면 기본음으로.
  Future<void> clearCustomSound() => update(
    state.copyWith(
      soundId: state.soundId == CustomChimeSound.customId
          ? AppSettings.defaultSoundId
          : null,
      customSoundPath: () => null,
      customSoundName: () => null,
    ),
  );
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

/// 앱에 들어 있는 `assets/audio/` 의 경고음 목록.
/// 폴더에 오디오 파일을 넣고 빌드하면 자동으로 선택지에 뜬다.
final chimeCatalogProvider = FutureProvider<ChimeCatalog>((ref) async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return ChimeCatalog.fromAssets(manifest.listAssets());
  } catch (_) {
    return ChimeCatalog.fallback;
  }
});

/// 지금 선택된 경고음 (없어진 파일이면 기본음).
final selectedSoundProvider = Provider<ChimeSound>((ref) {
  final s = ref.watch(settingsProvider);
  final catalog =
      ref.watch(chimeCatalogProvider).value ?? ChimeCatalog.fallback;
  return catalog.resolve(
    soundId: s.soundId,
    customPath: s.customSoundPath,
    customName: s.customSoundName,
  );
});

final customSoundStoreProvider = Provider(
  (ref) => CustomSoundStore(probe: ref.read(chimePlayerProvider).probe),
);
