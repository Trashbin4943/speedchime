import 'package:material_ui/material_ui.dart';

import '../core/app_settings.dart';

/// 2000년대 택시미터(VFD) 콘셉트: 검은 배경 위에 발광색 글자·선.
/// 발광색은 설정의 테마 색(하늘색 기본 / 빨간색 / 노란색)을 따른다.
/// OVER 경고색은 테마 색과 밝기·색상이 모두 다른 색으로 고른다.
@immutable
class MeterPalette extends ThemeExtension<MeterPalette> {
  const MeterPalette({
    required this.glow,
    required this.secondary,
    required this.line,
    required this.divider,
    required this.dim,
    required this.dimBorder,
    required this.litFill,
    required this.over,
  });

  static const background = Color(0xFF000000);
  static const panel = Color(0xFF03070A);

  /// 켜진 VFD 색. 글자·선·숫자.
  final Color glow;

  /// 보조 글자 (검은 배경 대비 4.5:1 이상).
  final Color secondary;
  final Color line;
  final Color divider;

  /// 꺼진 램프 글자·테두리.
  final Color dim;
  final Color dimBorder;

  /// 켜진 램프 바탕.
  final Color litFill;

  /// OVER 경고.
  final Color over;

  static const sky = MeterPalette(
    glow: Color(0xFF6FD8F5),
    secondary: Color(0xFF4FA9C2),
    line: Color(0xFF2E8AA3),
    divider: Color(0xFF1E5566),
    dim: Color(0xFF2B5967),
    dimBorder: Color(0xFF12323C),
    litFill: Color(0xFF0B2A33),
    over: Color(0xFFFF9A4D),
  );

  static const red = MeterPalette(
    glow: Color(0xFFFF5A4D),
    secondary: Color(0xFFD0645A),
    line: Color(0xFFA23A32),
    divider: Color(0xFF5E211C),
    dim: Color(0xFF6B2E28),
    dimBorder: Color(0xFF3A1411),
    litFill: Color(0xFF2E0D0A),
    over: Color(0xFFFFD54A),
  );

  static const yellow = MeterPalette(
    glow: Color(0xFFFFD54A),
    secondary: Color(0xFFC9A43A),
    line: Color(0xFFA08024),
    divider: Color(0xFF5A4714),
    dim: Color(0xFF6A5620),
    dimBorder: Color(0xFF2F260A),
    litFill: Color(0xFF2B2208),
    over: Color(0xFFFF5A4D),
  );

  static MeterPalette forTheme(MeterTheme t) => switch (t) {
    MeterTheme.sky => sky,
    MeterTheme.red => red,
    MeterTheme.yellow => yellow,
  };

  static MeterPalette of(BuildContext context) =>
      Theme.of(context).extension<MeterPalette>() ?? sky;

  @override
  MeterPalette copyWith({
    Color? glow,
    Color? secondary,
    Color? line,
    Color? divider,
    Color? dim,
    Color? dimBorder,
    Color? litFill,
    Color? over,
  }) {
    return MeterPalette(
      glow: glow ?? this.glow,
      secondary: secondary ?? this.secondary,
      line: line ?? this.line,
      divider: divider ?? this.divider,
      dim: dim ?? this.dim,
      dimBorder: dimBorder ?? this.dimBorder,
      litFill: litFill ?? this.litFill,
      over: over ?? this.over,
    );
  }

  @override
  MeterPalette lerp(MeterPalette? other, double t) {
    if (other == null) return this;
    return MeterPalette(
      glow: Color.lerp(glow, other.glow, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      line: Color.lerp(line, other.line, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dim: Color.lerp(dim, other.dim, t)!,
      dimBorder: Color.lerp(dimBorder, other.dimBorder, t)!,
      litFill: Color.lerp(litFill, other.litFill, t)!,
      over: Color.lerp(over, other.over, t)!,
    );
  }
}

/// 작은 영문 라벨(SPEEDCHIME, NORMAL, OVER …)용 고정폭 글꼴.
const meterMono = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['RobotoMono', 'Menlo', 'Courier'],
);

ThemeData meterTheme([MeterTheme theme = MeterTheme.sky]) {
  final p = MeterPalette.forTheme(theme);
  final scheme = ColorScheme.dark(
    surface: MeterPalette.background,
    onSurface: p.glow,
    onSurfaceVariant: p.secondary,
    primary: p.glow,
    onPrimary: MeterPalette.background,
    secondary: p.secondary,
    outline: p.line,
    outlineVariant: p.divider,
    error: p.over,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: MeterPalette.background,
    appBarTheme: AppBarTheme(
      backgroundColor: MeterPalette.background,
      foregroundColor: p.glow,
      elevation: 0,
    ),
    dividerColor: p.divider,
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: p.glow,
      displayColor: p.glow,
    ),
    extensions: [p],
  );
}
