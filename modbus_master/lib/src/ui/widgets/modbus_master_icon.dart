import 'package:flutter/material.dart';

/// Modbus Master (主站 / 客户端仿真器 MME) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，基于工业主机控制器芯片与标志性 "M" 轮询脉冲路径设计。
/// 支持任意缩放、自定义颜色与线宽，零第三方外部依赖。
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

    // 4. 主机标志性 "M" 轮询主动请求脉冲
    final mPath = Path()
      ..moveTo(7.5 * s, 15.5 * s)
      ..lineTo(7.5 * s, 9.5 * s)
      ..lineTo(12.0 * s, 14.0 * s)
      ..lineTo(16.5 * s, 9.5 * s)
      ..lineTo(16.5 * s, 15.5 * s);
    canvas.drawPath(mPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ModbusMasterIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
