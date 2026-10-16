import 'package:flutter/material.dart';

/// Modbus Slave (从站 / 服务端仿真器) 工业级矢量图标
///
/// 符合 24x24 工业图标网格规范，基于工业微控制器/从机芯片与标志性 "S" 响应路径设计。
/// 支持任意缩放、自定义颜色与线宽，零第三方依赖。
class ModbusSlaveIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const ModbusSlaveIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF10B981);

    return CustomPaint(
      size: Size(size, size),
      painter: _ModbusSlaveIconPainter(
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _ModbusSlaveIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ModbusSlaveIconPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 中央从机芯片/模块外壳 (4..20, 4..20)
    final chipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * s, 4 * s, 16 * s, 16 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(chipRRect, strokePaint);

    // 2. 顶部总线接线引脚 (Top Pins)
    canvas.drawLine(Offset(7 * s, 2 * s), Offset(7 * s, 4 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 2 * s), Offset(12 * s, 4 * s), strokePaint);
    canvas.drawLine(Offset(17 * s, 2 * s), Offset(17 * s, 4 * s), strokePaint);

    // 3. 底部总线接线引脚 (Bottom Pins)
    canvas.drawLine(Offset(7 * s, 20 * s), Offset(7 * s, 22 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 20 * s), Offset(12 * s, 22 * s), strokePaint);
    canvas.drawLine(Offset(17 * s, 20 * s), Offset(17 * s, 22 * s), strokePaint);

    // 4. 中央标志性 Modbus "S" 从站响应拓扑路径
    final path = Path()
      ..moveTo(15 * s, 8.5 * s)
      ..cubicTo(14.5 * s, 7.5 * s, 13.5 * s, 7.0 * s, 12.5 * s, 7.0 * s)
      ..lineTo(11.5 * s, 7.0 * s)
      ..arcToPoint(
        Offset(11.5 * s, 11.0 * s),
        radius: Radius.circular(2.0 * s),
        clockwise: false,
      )
      ..lineTo(12.5 * s, 11.0 * s)
      ..arcToPoint(
        Offset(12.5 * s, 15.0 * s),
        radius: Radius.circular(2.0 * s),
        clockwise: true,
      )
      ..lineTo(11.5 * s, 15.0 * s)
      ..cubicTo(10.5 * s, 15.0 * s, 9.5 * s, 14.5 * s, 9.0 * s, 13.5 * s);

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ModbusSlaveIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
