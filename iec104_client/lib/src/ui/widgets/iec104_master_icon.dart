import 'package:flutter/material.dart';

/// IEC 60870-5-104 Master Station (主站 / 调度中心) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，呈现带有全站总召唤与下发遥控指令的 SCADA 调度监控台。
/// 支持任意缩放、自定义颜色与线宽，零第三方外部依赖。
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
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF0284C7);

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
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 3 * s, 18 * s, 13 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(screenRect, strokePaint);

    // 2. 调度工作台底座与立柱
    canvas.drawLine(Offset(8 * s, 21 * s), Offset(16 * s, 21 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 16 * s), Offset(12 * s, 21 * s), strokePaint);

    // 3. 调度总召发射信标中心点
    canvas.drawCircle(Offset(12 * s, 11.5 * s), 1.2 * s, fillPaint);

    // 4. 屏内总召与遥控扫描波束
    final innerRect = Rect.fromCircle(center: Offset(12 * s, 11.5 * s), radius: 3.5 * s);
    canvas.drawArc(innerRect, -3.14159265 * 0.85, 3.14159265 * 0.7, false, strokePaint);

    final outerRect = Rect.fromCircle(center: Offset(12 * s, 11.5 * s), radius: 6.0 * s);
    canvas.drawArc(outerRect, -3.14159265 * 0.82, 3.14159265 * 0.64, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec104MasterIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
