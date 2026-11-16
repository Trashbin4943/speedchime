/// 택시미터식 7-세그먼트 숫자. 꺼진 칸도 희미하게 그려 "8" 이 비친다.
///
///  aaa
/// f   b
///  ggg
/// e   c
///  ddd
enum Seg { a, b, c, d, e, f, g }

abstract final class SevenSegment {
  static const _map = <String, String>{
    '0': 'abcdef',
    '1': 'bc',
    '2': 'abdeg',
    '3': 'abcdg',
    '4': 'bcfg',
    '5': 'acdfg',
    '6': 'acdefg',
    '7': 'abc',
    '8': 'abcdefg',
    '9': 'abcdfg',
    '-': 'g',
    ' ': '',
  };

  static Set<Seg> segmentsFor(String ch) {
    final on = _map[ch] ?? '';
    return {
      for (final s in Seg.values)
        if (on.contains(s.name)) s,
    };
  }

  /// [value] 를 [width] 자리로, 앞자리는 공백(꺼진 8). 넘치면 9 로 채움.
  static List<Set<Seg>> number(int value, {int width = 3}) {
    final max = int.parse('9' * width);
    final text = value.clamp(0, max).toString().padLeft(width);
    return [for (final ch in text.split('')) segmentsFor(ch)];
  }

  /// 전부 꺼진 자리 (대기 상태).
  static List<Set<Seg>> blank({int width = 3}) =>
      List.generate(width, (_) => <Seg>{});

  /// 가운데 막대만 (추적 중인데 GPS 속도 없음).
  static List<Set<Seg>> dashes({int width = 3}) =>
      List.generate(width, (_) => {Seg.g});
}
