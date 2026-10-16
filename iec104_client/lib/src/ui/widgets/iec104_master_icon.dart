import 'dart:math' as math;
import 'package:flutter/material.dart';

/// IEC 60870-5-104 Master Station (主站 / 调度中心) 工业级矢量图标
///
/// 符合 24x24 工业图标网格规范，支持任意缩放、自定义颜色与线宽。
class Iec104MasterIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const Iec104MasterIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.blueAccent;

    return CustomPaint(
      size: Size(size, size),
      painter: _Iec104MasterIconPainter(
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _Iec104MasterIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _Iec104MasterIconPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. SCADA 调度监控屏幕
    final screenRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * s, 3 * s, 20 * s, 14 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(screenRRect, strokePaint);

    // 2. 调度控制台底座与立柱
    canvas.drawLine(Offset(8 * s, 21 * s), Offset(16 * s, 21 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 17 * s), Offset(12 * s, 21 * s), strokePaint);

    // 3. 中央调度发射核心点
    canvas.drawCircle(Offset(12 * s, 12 * s), 1.2 * s, fillPaint);

    // 4. 内层遥控波束 (Inner Command Wave)
    final innerRect = Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 3.5 * s);
    canvas.drawArc(innerRect, -math.pi * 0.85, math.pi * 0.7, false, strokePaint);

    // 5. 外层总召广播波束 (Outer Interrogation Wave)
    final outerRect = Rect.fromCircle(center: Offset(12 * s, 12 * s), radius: 6.5 * s);
    canvas.drawArc(outerRect, -math.pi * 0.82, math.pi * 0.64, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec104MasterIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
