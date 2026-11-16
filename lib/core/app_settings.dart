/// 화면 테마 색 (택시미터 VFD 발광색). 기본은 하늘색.
enum MeterTheme {
  sky('하늘색'),
  red('빨간색'),
  yellow('노란색');

  const MeterTheme(this.label);

  final String label;

  static MeterTheme fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return sky;
  }
}

/// PRD 6. 저장 데이터: 기준 속도, 음량, 화면 켜짐 유지 + 테마 색 + 경고음.
class AppSettings {
  const AppSettings({
    this.thresholdKph = defaultThresholdKph,
    this.volume = 1.0,
    this.keepScreenOn = false,
    this.theme = MeterTheme.sky,
    this.soundId = defaultSoundId,
    this.customSoundPath,
    this.customSoundName,
  });

  /// 기본 경고음 (`ChimeCatalog.defaultSound.id`).
  static const String defaultSoundId = 'asset:assets/audio/chime.wav';

  /// F-03: 100/120/140 중 선택 (사용자 임의 입력은 비목표).
  static const List<int> thresholdOptions = [100, 120, 140];
  static const int defaultThresholdKph = 120;

  final int thresholdKph;
  final double volume;
  final bool keepScreenOn;
  final MeterTheme theme;

  /// 선택한 경고음 id (`ChimeSound.id`).
  final String soundId;

  /// 내 사운드: 앱 저장소에 복사된 파일 경로와 원래 파일 이름. 없으면 null.
  final String? customSoundPath;
  final String? customSoundName;

  /// [customSoundPath]·[customSoundName] 은 함수로 넘겨야 null 로 지울 수 있다.
  AppSettings copyWith({
    int? thresholdKph,
    double? volume,
    bool? keepScreenOn,
    MeterTheme? theme,
    String? soundId,
    String? Function()? customSoundPath,
    String? Function()? customSoundName,
  }) {
    return AppSettings(
      thresholdKph: thresholdKph ?? this.thresholdKph,
      volume: volume ?? this.volume,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      theme: theme ?? this.theme,
      soundId: soundId ?? this.soundId,
      customSoundPath: customSoundPath != null
          ? customSoundPath()
          : this.customSoundPath,
      customSoundName: customSoundName != null
          ? customSoundName()
          : this.customSoundName,
    );
  }
}
