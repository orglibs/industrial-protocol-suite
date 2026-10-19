import 'package:flutter/material.dart';

/// IEC 61850 Server / Virtual IED (智能变电站微机保护测控装置 / 服务端) 极简工业级矢量图标
///
/// 遵循 24x24 极简矢量图标设计规范，呈现 19 英寸机架式 IED，配备过程层光纤接口与断路器跳闸方波脉冲 (GOOSE Trip)。
/// 支持任意缩放、自定义颜色、可选双色重音与线宽调节，零第三方外部依赖。
class Iec61850ServerIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? accentColor;
  final double strokeWidth;

  const Iec61850ServerIcon({
    super.key,
    this.size = 24.0,
    this.color,
    this.accentColor,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? const Color(0xFF06B6D4);
    final accent = accentColor ?? iconColor;

    return CustomPaint(
      size: Size(size, size),
      painter: _Iec61850ServerIconPainter(
        color: iconColor,
        accentColor: accent,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _Iec61850ServerIconPainter extends CustomPainter {
  final Color color;
  final Color accentColor;
  final double strokeWidth;

  _Iec61850ServerIconPainter({
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
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. 顶部双重化光纤以太网收发器接口
    canvas.drawLine(Offset(7 * s, 2 * s), Offset(7 * s, 5 * s), strokePaint);
    canvas.drawLine(Offset(11 * s, 2 * s), Offset(11 * s, 5 * s), strokePaint);

    // 2. 19 英寸 IED 机箱外框 (3..21, 5..20)
    final chassisRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 5 * s, 18 * s, 15 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(chassisRRect, strokePaint);

    // 3. 面板水平分界线
    canvas.drawLine(Offset(3 * s, 10 * s), Offset(21 * s, 10 * s), strokePaint);

    // 4. 面板运行状态 LED
    canvas.drawCircle(Offset(17 * s, 7.5 * s), 1.0 * s, fillPaint);

    // 5. 毫秒级断路器跳闸方波脉冲 (GOOSE XCBR Trip Pulse)
    final tripPath = Path()
      ..moveTo(6 * s, 15.5 * s)
      ..lineTo(9 * s, 15.5 * s)
      ..lineTo(9 * s, 12 * s)
      ..lineTo(13 * s, 12 * s)
      ..lineTo(13 * s, 15.5 * s)
      ..lineTo(18 * s, 15.5 * s);
    canvas.drawPath(tripPath, accentStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec61850ServerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
