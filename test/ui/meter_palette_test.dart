import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speedchime/core/app_settings.dart';
import 'package:speedchime/ui/meter_theme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _hue(Color c) => HSVColor.fromColor(c).hue;

void main() {
  for (final t in MeterTheme.values) {
    final p = MeterPalette.forTheme(t);

    test('${t.label}: 글자색이 검은 배경에서 4.5:1 이상', () {
      for (final c in [p.glow, p.secondary, p.over]) {
        expect(
          _contrast(c, MeterPalette.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(c, MeterPalette.panel), greaterThanOrEqualTo(4.5));
      }
    });

    test('${t.label}: OVER 색은 발광색과 확실히 구분됨', () {
      // 색상이 크게 다르거나(하늘색↔주황), 밝기가 크게 다르거나(빨강↔노랑).
      final hueGap = (_hue(p.over) - _hue(p.glow)).abs();
      final gap = math.min(hueGap, 360 - hueGap);
      expect(
        gap >= 90 || _contrast(p.over, p.glow) >= 1.8,
        isTrue,
        reason: 'hue gap $gap°, contrast ${_contrast(p.over, p.glow)}',
      );
    });

    test('${t.label}: 테마가 팔레트를 실어 나름', () {
      expect(meterTheme(t).extension<MeterPalette>(), p);
    });
  }

  test('저장된 이름 → 테마, 모르는 값은 하늘색', () {
    expect(MeterTheme.fromName('red'), MeterTheme.red);
    expect(MeterTheme.fromName(null), MeterTheme.sky);
    expect(MeterTheme.fromName('purple'), MeterTheme.sky);
  });
}
