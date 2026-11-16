import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_settings.dart';

/// F-03: 앱 재실행 후에도 설정 유지.
class SettingsRepository {
  SettingsRepository(this._prefs);

  static const _kThreshold = 'threshold_kph';
  static const _kVolume = 'volume';
  static const _kKeepScreenOn = 'keep_screen_on';
  static const _kTheme = 'meter_theme';
  static const _kSound = 'chime_sound';
  static const _kCustomPath = 'custom_sound_path';
  static const _kCustomName = 'custom_sound_name';
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
      theme: MeterTheme.fromName(_prefs.getString(_kTheme)),
      soundId: _prefs.getString(_kSound) ?? AppSettings.defaultSoundId,
      customSoundPath: _prefs.getString(_kCustomPath),
      customSoundName: _prefs.getString(_kCustomName),
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt(_kThreshold, s.thresholdKph);
    await _prefs.setDouble(_kVolume, s.volume);
    await _prefs.setBool(_kKeepScreenOn, s.keepScreenOn);
    await _prefs.setString(_kTheme, s.theme.name);
    await _prefs.setString(_kSound, s.soundId);
    await _setOrRemove(_kCustomPath, s.customSoundPath);
    await _setOrRemove(_kCustomName, s.customSoundName);
  }

  Future<void> _setOrRemove(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  bool get disclaimerAccepted => _prefs.getBool(_kDisclaimerAccepted) ?? false;

  Future<void> acceptDisclaimer() => _prefs.setBool(_kDisclaimerAccepted, true);
}
