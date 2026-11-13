import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_settings.dart';

/// F-03: 앱 재실행 후에도 설정 유지.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _kThreshold = 'threshold_kph';
  static const _kVolume = 'volume';
  static const _kKeepScreenOn = 'keep_screen_on';
  static const _kDisclaimerAccepted = 'disclaimer_accepted';

  final SharedPreferencesWithCache _prefs;

  static Future<SettingsRepository> create() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    return SettingsRepository(prefs);
  }

  AppSettings load() {
    final t = _prefs.getInt(_kThreshold);
    return AppSettings(
      thresholdKph: AppSettings.thresholdOptions.contains(t)
          ? t!
          : AppSettings.defaultThresholdKph,
      volume: _prefs.getDouble(_kVolume) ?? 1.0,
      keepScreenOn: _prefs.getBool(_kKeepScreenOn) ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kThreshold, s.thresholdKph);
    await _prefs.setDouble(_kVolume, s.volume);
    await _prefs.setBool(_kKeepScreenOn, s.keepScreenOn);
  }

  bool get disclaimerAccepted => _prefs.getBool(_kDisclaimerAccepted) ?? false;

  Future<void> acceptDisclaimer() => _prefs.setBool(_kDisclaimerAccepted, true);
}
