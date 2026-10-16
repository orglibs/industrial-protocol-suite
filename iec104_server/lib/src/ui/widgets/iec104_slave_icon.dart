import 'package:flutter/material.dart';

/// IEC 60870-5-104 Slave Station (从站 / 厂站 RTU) 工业级矢量图标
///
/// 符合 24x24 工业图标网格规范，支持任意缩放、自定义颜色与线宽。
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

    // 1. RTU 工业机箱外框 (4..20, 3..21)
    final boxRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * s, 3 * s, 16 * s, 18 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(boxRRect, strokePaint);

    // 2. 左右机柜安装挂耳 (Mounting Ears)
    canvas.drawLine(Offset(2 * s, 7 * s), Offset(4 * s, 7 * s), strokePaint);
    canvas.drawLine(Offset(2 * s, 17 * s), Offset(4 * s, 17 * s), strokePaint);
    canvas.drawLine(Offset(20 * s, 7 * s), Offset(22 * s, 7 * s), strokePaint);
    canvas.drawLine(Offset(20 * s, 17 * s), Offset(22 * s, 17 * s), strokePaint);

    // 3. 面板水平分界线
    canvas.drawLine(Offset(4 * s, 9 * s), Offset(20 * s, 9 * s), strokePaint);

    // 4. 顶部指示灯与通信状态条
    canvas.drawCircle(Offset(7.5 * s, 6 * s), 1.0 * s, fillPaint);
    canvas.drawCircle(Offset(11 * s, 6 * s), 1.0 * s, fillPaint);
    canvas.drawLine(Offset(14.5 * s, 6 * s), Offset(17 * s, 6 * s), strokePaint);

    // 5. 突发事件遥测采样波形 (Spontaneous Waveform: COT=3)
    final path = Path()
      ..moveTo(7 * s, 14.5 * s)
      ..lineTo(9 * s, 14.5 * s)
      ..lineTo(11 * s, 11 * s)
      ..lineTo(13 * s, 16 * s)
      ..lineTo(15 * s, 13 * s)
      ..lineTo(17 * s, 14.5 * s);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec104SlaveIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
