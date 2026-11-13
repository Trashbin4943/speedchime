import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_settings.dart';
import 'services/chime_player.dart';
import 'services/location_service.dart';
import 'services/permission_service.dart';
import 'services/settings_repository.dart';

/// Overridden in main() after SharedPreferences is loaded.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('override in ProviderScope'),
);

final locationServiceProvider = Provider((ref) => LocationService());
final permissionServiceProvider = Provider((ref) => PermissionService());

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
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
