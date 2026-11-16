import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../core/seven_segment.dart';

/// 7-세그먼트 숫자 줄. 꺼진 칸은 8% 로 비치고, 켜진 칸은 발광한다.
class SevenSegmentDisplay extends StatelessWidget {
  const SevenSegmentDisplay({
    super.key,
    required this.digits,
    required this.digitWidth,
    required this.digitHeight,
    this.gap = 10,
    required this.color,
    required this.semanticsLabel,
  });

  final List<Set<Seg>> digits;
  final double digitWidth;
  final double digitHeight;
  final double gap;
  final Color color;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            CustomPaint(
              size: Size(digitWidth, digitHeight),
              painter: _DigitPainter(digits[i], color),
            ),
          ],
        ],
      ),
    );
  }
}

class _DigitPainter extends CustomPainter {
  _DigitPainter(this.on, this.color);

  final Set<Seg> on;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = w * 0.157; // 세그먼트 두께
    final inset = t * 0.9;
    final vLen = h / 2 - inset * 1.1;
    final r = Radius.circular(t * 0.27);

    final rects = <Seg, Rect>{
      Seg.a: Rect.fromLTWH(inset, 0, w - inset * 2, t),
      Seg.g: Rect.fromLTWH(inset, h / 2 - t / 2, w - inset * 2, t),
      Seg.d: Rect.fromLTWH(inset, h - t, w - inset * 2, t),
      Seg.f: Rect.fromLTWH(0, t * 0.6, t, vLen),
      Seg.b: Rect.fromLTWH(w - t, t * 0.6, t, vLen),
      Seg.e: Rect.fromLTWH(0, h - t * 0.6 - vLen, t, vLen),
      Seg.c: Rect.fromLTWH(w - t, h - t * 0.6 - vLen, t, vLen),
    };

    // VFD 처럼 살짝 기울인다 (skewX -7°), 아래를 기준으로.
    canvas.save();
    canvas.translate(0, h);
    canvas.transform(
      (Matrix4.identity()..setEntry(0, 1, -math.tan(7 * math.pi / 180)))
          .storage,
    );
    canvas.translate(0, -h);

    final offPaint = Paint()..color = color.withValues(alpha: 0.08);
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.6);
    final onPaint = Paint()..color = color;

    for (final e in rects.entries) {
      final rr = RRect.fromRectAndRadius(e.value, r);
      if (on.contains(e.key)) {
        canvas.drawRRect(rr, glowPaint);
        canvas.drawRRect(rr, onPaint);
      } else {
        canvas.drawRRect(rr, offPaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DigitPainter old) =>
      old.color != color || !_sameSet(old.on, on);

  static bool _sameSet(Set<Seg> a, Set<Seg> b) =>
      a.length == b.length && a.containsAll(b);
}
