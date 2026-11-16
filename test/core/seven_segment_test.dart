import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/seven_segment.dart';

void main() {
  test('숫자별 세그먼트', () {
    expect(SevenSegment.segmentsFor('8'), Seg.values.toSet());
    expect(SevenSegment.segmentsFor('1'), {Seg.b, Seg.c});
    expect(SevenSegment.segmentsFor(' '), isEmpty);
    expect(SevenSegment.segmentsFor('-'), {Seg.g});
  });

  test('앞자리는 꺼진 칸, 넘치면 999', () {
    final d = SevenSegment.number(7);
    expect(d, hasLength(3));
    expect(d[0], isEmpty);
    expect(d[1], isEmpty);
    expect(d[2], SevenSegment.segmentsFor('7'));
    expect(SevenSegment.number(1234).every((s) => s.length == 6), isTrue);
  });

  test('대기·속도 없음 표시', () {
    expect(SevenSegment.blank().every((s) => s.isEmpty), isTrue);
    expect(SevenSegment.dashes().every((s) => s.length == 1), isTrue);
  });
}
