import 'package:flutter/material.dart';

/// IEC 60870-5-104 Server Station (从站 / RTU 厂站) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，呈现向上广播发射遥测数据的 RTU 终端机箱。
/// 支持任意缩放、自定义颜色与线宽，零第三方外部依赖。
class Iec104SlaveIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const Iec104SlaveIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFFF59E0B);

    return CustomPaint(
      size: Size(size, size),
      painter: _Iec104SlaveIconPainter(
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _Iec104SlaveIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _Iec104SlaveIconPainter({required this.color, required this.strokeWidth});

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

    // 1. RTU 工业机箱外框 (3..21, 10..21)
    final rtuRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 10 * s, 18 * s, 11 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(rtuRect, strokePaint);

    // 2. 状态指示 LED
    canvas.drawCircle(Offset(7 * s, 15.5 * s), 1.0 * s, fillPaint);

    // 3. 突发事件遥测采样波形
    final wavePath = Path()
      ..moveTo(11 * s, 15.5 * s)
      ..lineTo(12.5 * s, 15.5 * s)
      ..lineTo(14 * s, 13 * s)
      ..lineTo(15.5 * s, 17 * s)
      ..lineTo(17 * s, 15 * s)
      ..lineTo(18.5 * s, 15.5 * s);
    canvas.drawPath(wavePath, strokePaint);

    // 4. 向上发射的遥测广播无线波束 (Concentric Telemetry Waves)
    final outerRect = Rect.fromCircle(center: Offset(12 * s, 10 * s), radius: 5.5 * s);
    canvas.drawArc(outerRect, -3.14159265 * 0.85, 3.14159265 * 0.7, false, strokePaint);

    final innerRect = Rect.fromCircle(center: Offset(12 * s, 10 * s), radius: 2.8 * s);
    canvas.drawArc(innerRect, -3.14159265 * 0.82, 3.14159265 * 0.64, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec104SlaveIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
