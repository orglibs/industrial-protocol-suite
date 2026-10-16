import 'package:flutter/material.dart';

/// IEC 61850 Client Station (站控层工程工作站 / 客户端仿真器) 工业级矢量图标
///
/// 严格遵循 24x24 工业图标网格与 Lucide 矢量规范。
/// 呈现变电站站控层 SCADA 监控控制台，内嵌 SCL 数据模型对象树 (IED ➔ LD ➔ LN ➔ DO) 与 SBO 执行指示。
/// 支持任意缩放、自定义颜色、可选双色重音与线宽调节，零外部依赖。
class Iec61850ClientIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final double strokeWidth;

  const Iec61850ClientIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.accentColor,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF0284C7);
    final accent = accentColor ?? iconColor;

    return CustomPaint(
      size: Size(size, size),
      painter: _Iec61850ClientIconPainter(
        color: iconColor,
        accentColor: accent,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _Iec61850ClientIconPainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final double strokeWidth;

  _Iec61850ClientIconPainter({
    required this.color,
    required this.accentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final accentStrokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // 1. 站控层 SCADA 监控屏幕外框 (2..22, 3..17)
    final screenRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2 * s, 3 * s, 20 * s, 14 * s),
      Radius.circular(2.5 * s),
    );
    canvas.drawRRect(screenRRect, strokePaint);

    // 2. 调度工作站控制台底座与立柱
    canvas.drawLine(Offset(8 * s, 21 * s), Offset(16 * s, 21 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 17 * s), Offset(12 * s, 21 * s), strokePaint);

    // 3. 屏幕内 SCL 数据模型对象树 (Object Hierarchy Tree)
    // 树主干 (Trunk)
    canvas.drawLine(Offset(6 * s, 7 * s), Offset(6 * s, 13 * s), strokePaint);
    // 上分支 (LD0 逻辑设备分支)
    canvas.drawLine(Offset(6 * s, 8 * s), Offset(9 * s, 8 * s), strokePaint);
    // 下分支 (LN 逻辑节点分支)
    canvas.drawLine(Offset(6 * s, 12 * s), Offset(9 * s, 12 * s), strokePaint);

    // 4. 数据对象行与 SBO 控制状态条
    canvas.drawLine(Offset(12 * s, 8 * s), Offset(16 * s, 8 * s), accentStrokePaint);
    canvas.drawLine(Offset(12 * s, 12 * s), Offset(17 * s, 12 * s), accentStrokePaint);

    // 5. 目标活动节点脉冲 (Active Node Target)
    canvas.drawCircle(Offset(18 * s, 8 * s), 0.9 * s, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _Iec61850ClientIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
