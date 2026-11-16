import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../core/gait.dart';

/// 택시미터 콘셉트의 달리는 말. 속도가 빠를수록 다리를 빨리 휘두른다.
///
/// 위상(phase)을 stride 단위로 누적하므로, 속도가 바뀌어도 포즈가 튀지 않고
/// 빠르기만 연속으로 바뀐다. 시스템 "애니메이션 줄이기" 설정이면 멈춰 그린다.
class RunningHorse extends StatefulWidget {
  const RunningHorse({
    super.key,
    required this.gait,
    this.width = 176,
    required this.color,
  });

  final Gait gait;
  final double width;
  final Color color;

  @override
  State<RunningHorse> createState() => _RunningHorseState();
}

class _RunningHorseState extends State<RunningHorse>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;
  double _phase = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RunningHorse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  bool get _animate =>
      widget.gait.moving &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (_animate && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    setState(() => _phase += dt / widget.gait.strideSeconds);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '달리는 말: ${widget.gait.tier.label}',
      excludeSemantics: true,
      child: CustomPaint(
        size: Size(widget.width, widget.width * 100 / 160),
        painter: _HorsePainter(
          widget.gait.moving ? HorsePose.at(_phase) : HorsePose.standing,
          widget.color,
        ),
      ),
    );
  }
}

/// 160×100 좌표계의 선 그림 (디자인 시안과 같은 형태).
class _HorsePainter extends CustomPainter {
  _HorsePainter(this.pose, this.color);

  final HorsePose pose;
  final Color color;

  static final _body = Path()
    ..moveTo(48, 40)
    ..cubicTo(56, 31, 88, 30, 100, 36)
    ..cubicTo(106, 39, 106, 50, 98, 53)
    ..cubicTo(86, 57, 62, 57, 52, 53)
    ..cubicTo(44, 50, 42, 44, 48, 40)
    ..close();
  static final _head = Path()
    ..moveTo(98, 38)
    ..cubicTo(102, 30, 106, 22, 110, 16)
    ..cubicTo(113, 11, 120, 11, 124, 15)
    ..lineTo(131, 22)
    ..cubicTo(133, 25, 130, 27, 127, 26)
    ..lineTo(118, 24)
    ..cubicTo(114, 27, 110, 32, 104, 42)
    ..moveTo(114, 12)
    ..lineTo(116, 6)
    ..lineTo(119, 12);
  static final _mane = Path()
    ..moveTo(110, 17)
    ..cubicTo(104, 20, 100, 26, 98, 33)
    ..moveTo(107, 21)
    ..lineTo(102, 19)
    ..moveTo(104, 26)
    ..lineTo(99, 25);
  static final _tail = Path()
    ..moveTo(48, 42)
    ..cubicTo(38, 38, 30, 42, 24, 52)
    ..moveTo(46, 46)
    ..cubicTo(38, 46, 33, 52, 30, 58);

  // 다리: 엉덩이/어깨(첫 점)를 축으로 회전.
  static Path _leg(List<double> p) {
    final path = Path()..moveTo(p[0], p[1]);
    for (var i = 2; i < p.length; i += 2) {
      path.lineTo(p[i], p[i + 1]);
    }
    return path;
  }

  static final _frontA = _leg([96, 52, 99, 68, 95, 82, 99, 84]);
  static final _frontB = _leg([90, 54, 89, 69, 93, 82, 97, 84]);
  static final _hindA = _leg([58, 53, 54, 68, 58, 82, 62, 84]);
  static final _hindB = _leg([52, 51, 45, 64, 46, 82, 50, 84]);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 160, size.height / 100);

    final crisp = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    void stroke(Path p, {double width = 2.6}) {
      canvas.drawPath(p, glow..strokeWidth = width + 1.6);
      canvas.drawPath(p, crisp..strokeWidth = width);
    }

    void rotated(Offset pivot, double deg, void Function() draw) {
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(deg * math.pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);
      draw();
      canvas.restore();
    }

    // 바닥 점선: 6 켜짐 / 12 꺼짐, 왼쪽으로 흐른다.
    final road = Path();
    for (var x = -pose.roadOffset % 18 - 18; x < 158; x += 18) {
      final a = math.max(2.0, x);
      final b = math.min(158.0, x + 6);
      if (b > a) {
        road
          ..moveTo(a, 91)
          ..lineTo(b, 91);
      }
    }
    stroke(road, width: 1.6);

    canvas.translate(0, pose.bodyY);
    // 뒤쪽 다리 먼저, 몸, 앞쪽 다리 순 (시안과 같은 겹침 순서).
    rotated(const Offset(58, 53), pose.hindA, () => stroke(_hindA));
    rotated(const Offset(90, 54), pose.frontB, () => stroke(_frontB));
    stroke(_body);
    stroke(_head);
    stroke(_mane, width: 1.8);
    canvas.drawCircle(const Offset(120, 17), 1.3, Paint()..color = color);
    rotated(const Offset(48, 40), pose.tail, () => stroke(_tail, width: 2));
    rotated(const Offset(52, 51), pose.hindB, () => stroke(_hindB));
    rotated(const Offset(96, 52), pose.frontA, () => stroke(_frontA));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_HorsePainter old) =>
      old.pose != pose || old.color != color;
}
