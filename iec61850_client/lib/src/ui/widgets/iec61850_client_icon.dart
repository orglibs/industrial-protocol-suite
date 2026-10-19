import 'package:flutter/material.dart';

/// IEC 61850 Client Station (变电站站控层工程工作站 / 客户端) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，呈现变电站站控层 SCADA 监控台，内嵌 SCL 数据模型层次树 (IED ➔ LN ➔ DO)。
/// 支持任意缩放、自定义颜色、可选双色重音与线宽调节，零第三方外部依赖。
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

    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // 1. 站控层 SCADA 监控屏幕外框 (3..21, 3..16)
    final screenRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 3 * s, 18 * s, 13 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(screenRRect, strokePaint);

    // 2. 控制台底座与立柱
    canvas.drawLine(Offset(8 * s, 21 * s), Offset(16 * s, 21 * s), strokePaint);
    canvas.drawLine(Offset(12 * s, 16 * s), Offset(12 * s, 21 * s), strokePaint);

    // 3. 屏幕内 SCL 数据模型对象树 (Object Hierarchy Tree)
    final treePath = Path()
      ..moveTo(7 * s, 6.5 * s)
      ..lineTo(7 * s, 12.5 * s)
      ..lineTo(11 * s, 12.5 * s)
      ..moveTo(7 * s, 9.5 * s)
      ..lineTo(11 * s, 9.5 * s);
    canvas.drawPath(treePath, strokePaint);

    // 4. 数据对象节点指示点
    canvas.drawCircle(Offset(15 * s, 6.5 * s), 1.0 * s, accentPaint);
    canvas.drawCircle(Offset(15 * s, 9.5 * s), 1.0 * s, accentPaint);
    canvas.drawCircle(Offset(15 * s, 12.5 * s), 1.0 * s, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _Iec61850ClientIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
