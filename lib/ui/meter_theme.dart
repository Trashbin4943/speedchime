import 'package:material_ui/material_ui.dart';

/// 2000년대 택시미터(VFD) 콘셉트: 검은 배경, 하늘색 글자·선, 은은한 발광.
abstract final class MeterColors {
  static const background = Color(0xFF000000);
  static const panel = Color(0xFF03070A);

  /// 켜진 VFD 색. 글자·선·숫자.
  static const glow = Color(0xFF6FD8F5);

  /// 보조 글자 (검은 배경 대비 7:1 이상).
  static const secondary = Color(0xFF4FA9C2);
  static const line = Color(0xFF2E8AA3);
  static const divider = Color(0xFF1E5566);

  /// 꺼진 램프.
  static const dim = Color(0xFF2B5967);
  static const dimBorder = Color(0xFF12323C);
  static const litFill = Color(0xFF0B2A33);

  /// OVER 경고에만 쓰는 주황 (미터기의 주황 숫자).
  static const over = Color(0xFFFF9A4D);
}

/// 작은 영문 라벨(SPEEDCHIME, NORMAL, OVER …)용 고정폭 글꼴.
const meterMono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['RobotoMono', 'Menlo', 'Courier'],
);

ThemeData meterTheme() {
  const scheme = ColorScheme.dark(
    surface: MeterColors.background,
    onSurface: MeterColors.glow,
    primary: MeterColors.glow,
    onPrimary: MeterColors.background,
    secondary: MeterColors.secondary,
    outline: MeterColors.line,
    outlineVariant: MeterColors.divider,
    error: MeterColors.over,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: MeterColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: MeterColors.background,
      foregroundColor: MeterColors.glow,
      elevation: 0,
    ),
    dividerColor: MeterColors.divider,
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: MeterColors.glow,
      displayColor: MeterColors.glow,
    ),
  );
}
