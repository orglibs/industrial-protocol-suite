import 'package:flutter/material.dart';

/// Modbus Slave (从站 / 服务端仿真器 MSE) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，基于工业从机芯片与标志性 "S" 寄存器响应路径设计。
/// 支持任意缩放、自定义颜色与线宽，零第三方外部依赖。
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

    // 1. 工业芯片封装主体
    final chipRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4 * s, 4 * s, 16 * s, 16 * s),
      Radius.circular(3 * s),
    );
    canvas.drawRRect(chipRRect, strokePaint);

    // 2. 顶部总线引脚
    canvas.drawLine(Offset(7 * s, 1.5 * s), Offset(7 * s, 4 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 1.5 * s), Offset(12 * s, 4 * s), strokePaint);
    canvas.drawLine(Offset(17 * s, 1.5 * s), Offset(17 * s, 4 * s), strokePaint);

    // 3. 底部总线引脚
    canvas.drawLine(Offset(7 * s, 20 * s), Offset(7 * s, 22.5 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 20 * s), Offset(12 * s, 22.5 * s), strokePaint);
    canvas.drawLine(Offset(17 * s, 20 * s), Offset(17 * s, 22.5 * s), strokePaint);

    // 4. 从机标志性 "S" 寄存器响应数据流路径
    final sPath = Path()
      ..moveTo(15 * s, 8.5 * s)
      ..cubicTo(14 * s, 7.5 * s, 12 * s, 7.0 * s, 11 * s, 7.0 * s)
      ..cubicTo(9.5 * s, 7.0 * s, 9 * s, 8.0 * s, 9 * s, 9.0 * s)
      ..cubicTo(9 * s, 11.0 * s, 15 * s, 10.5 * s, 15 * s, 13.0 * s)
      ..cubicTo(15 * s, 14.5 * s, 13.5 * s, 15.0 * s, 12 * s, 15.0 * s)
      ..cubicTo(10 * s, 15.0 * s, 9.5 * s, 14.0 * s, 9 * s, 13.5 * s);
    canvas.drawPath(sPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ModbusSlaveIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
