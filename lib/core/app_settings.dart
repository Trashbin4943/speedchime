/// PRD 6. 저장 데이터: 기준 속도, 음량, 화면 켜짐 유지 세 가지뿐.
class AppSettings {
  const AppSettings({
    this.thresholdKph = defaultThresholdKph,
    this.volume = 1.0,
    this.keepScreenOn = false,
  });

  /// F-03: 100/120/140 중 선택 (사용자 임의 입력은 비목표).
  static const List<int> thresholdOptions = [100, 120, 140];
  static const int defaultThresholdKph = 120;

  final int thresholdKph;
  final double volume;
  final bool keepScreenOn;

  AppSettings copyWith({
    int? thresholdKph,
    double? volume,
    bool? keepScreenOn,
  }) {
    return AppSettings(
      thresholdKph: thresholdKph ?? this.thresholdKph,
      volume: volume ?? this.volume,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    );
  }
}
