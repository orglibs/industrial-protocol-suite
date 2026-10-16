import 'package:flutter/material.dart';

/// Modbus Master (主站 / 客户端仿真器) 工业级矢量图标
///
/// 符合 24x24 工业图标网格规范，基于工业微控制器/总线芯片与标志性 "M" 轮询路径设计。
/// 支持任意缩放、自定义颜色与线宽，零第三方依赖。
class ModbusMasterIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const ModbusMasterIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF6366F1);

    return CustomPaint(
      size: Size(size, size),
      painter: _ModbusMasterIconPainter(
        color: iconColor,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _ModbusMasterIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _ModbusMasterIconPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. 中央工业主控芯片/模块外壳 (4..20, 4..20)
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

    // 4. 中央标志性 Modbus "M" 轮询拓扑路径
    final path = Path()
      ..moveTo(7 * s, 15 * s)
      ..lineTo(7 * s, 9 * s)
      ..lineTo(12 * s, 13.5 * s)
      ..lineTo(17 * s, 9 * s)
      ..lineTo(17 * s, 15 * s);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ModbusMasterIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
