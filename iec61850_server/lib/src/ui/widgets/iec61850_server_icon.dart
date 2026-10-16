import 'package:flutter/material.dart';

/// IEC 61850 Server / Virtual IED (智能变电站微机保护测控装置 / 服务端) 工业级矢量图标
///
/// 严格遵循 24x24 工业图标网格与 Lucide 矢量规范。
/// 呈现 19 英寸机架式微机保护测控装置 (IED)，顶部具有双重化过程层/站控层光纤收发器，
/// 下部配备毫秒级断路器分合闸跳闸方波脉冲 (GOOSE Trip Pulse)。
/// 支持任意缩放、自定义颜色、双色重音 (如 Cyan 机箱 + Amber 跳闸脉冲) 与线宽调节，零外部依赖。
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
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // 1. 19 英寸 IED 机架外壳 (3..21, 4..20)
    final chassisRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 4 * s, 18 * s, 16 * s),
      Radius.circular(2.2 * s),
    );
    canvas.drawRRect(chassisRRect, strokePaint);

    // 2. 面板水平分界线
    canvas.drawLine(Offset(3 * s, 10 * s), Offset(21 * s, 10 * s), strokePaint);

    // 3. 顶部双重化光纤以太网收发器接口 (LC Duplex Optical Transceivers)
    canvas.drawLine(Offset(7 * s, 2 * s), Offset(7 * s, 4 * s), strokePaint);
    canvas.drawLine(Offset(11 * s, 2 * s), Offset(11 * s, 4 * s), strokePaint);

    // 4. 面板运行状态 LED 指示灯
    canvas.drawCircle(Offset(16.5 * s, 7 * s), 1.0 * s, fillPaint);

    // 5. 毫秒级断路器跳闸方波脉冲 (GOOSE XCBR Trip Pulse Waveform)
    final tripPath = Path()
      ..moveTo(6 * s, 16 * s)
      ..lineTo(9.5 * s, 16 * s)
      ..lineTo(9.5 * s, 12 * s)
      ..lineTo(14 * s, 12 * s)
      ..lineTo(14 * s, 16 * s)
      ..lineTo(18 * s, 16 * s);
    canvas.drawPath(tripPath, accentStrokePaint);
  }

  @override
  bool shouldRepaint(covariant _Iec61850ServerIconPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
