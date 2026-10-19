import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/register_model.dart';
import '../../models/slave_model.dart';
import '../../services/polling_service.dart';

class ChartTab extends StatefulWidget {
  final PollingService pollingService;
  final ConnectionConfig config;

  const ChartTab({
    super.key,
    required this.pollingService,
    required this.config,
  });

  @override
  State<ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<ChartTab> {
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;
  RegisterModel? _selectedRegister;

  final List<double> _history = [];
  static const int _maxPoints = 50;

  @override
  void initState() {
    super.initState();
    _initSelection();
    widget.pollingService.onGroupUpdated.listen((g) {
      if (mounted && g == _selectedGroup && _selectedRegister != null) {
        setState(() {
          _history.add(_selectedRegister!.rawValue.toDouble());
          if (_history.length > _maxPoints) {
            _history.removeAt(0);
          }
        });
      }
    });
  }

  void _initSelection() {
    if (widget.config.slaves.isNotEmpty) {
      _selectedSlave = widget.config.slaves.first;
      if (_selectedSlave!.groups.isNotEmpty) {
        _selectedGroup = _selectedSlave!.groups.first;
        if (_selectedGroup!.registers.isNotEmpty) {
          _selectedRegister = _selectedGroup!.registers.first;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.slaves.isEmpty) {
      return Center(child: Text(AppI18n.instance.t('noSlaveHint')));
    }

    if (_selectedSlave == null || !widget.config.slaves.contains(_selectedSlave)) {
      _selectedSlave = widget.config.slaves.first;
    }
    if (_selectedGroup == null || !_selectedSlave!.groups.contains(_selectedGroup)) {
      _selectedGroup = _selectedSlave!.groups.isNotEmpty ? _selectedSlave!.groups.first : null;
    }
    if (_selectedRegister == null && _selectedGroup != null && _selectedGroup!.registers.isNotEmpty) {
      _selectedRegister = _selectedGroup!.registers.first;
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // Selector bar
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<SlaveModel>(
                value: _selectedSlave,
                underline: const SizedBox(),
                items: widget.config.slaves.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.displayName));
                }).toList(),
                onChanged: (s) {
                  setState(() {
                    _selectedSlave = s;
                    _selectedGroup = s?.groups.isNotEmpty == true ? s!.groups.first : null;
                    _selectedRegister = _selectedGroup?.registers.isNotEmpty == true ? _selectedGroup!.registers.first : null;
                    _history.clear();
                  });
                },
              ),
              if (_selectedSlave != null && _selectedSlave!.groups.isNotEmpty)
                DropdownButton<RegisterGroupModel>(
                  value: _selectedGroup,
                  underline: const SizedBox(),
                  items: _selectedSlave!.groups.map((g) {
                    return DropdownMenuItem(value: g, child: Text(g.displayGroupName));
                  }).toList(),
                  onChanged: (g) {
                    setState(() {
                      _selectedGroup = g;
                      _selectedRegister = g?.registers.isNotEmpty == true ? g!.registers.first : null;
                      _history.clear();
                    });
                  },
                ),
              if (_selectedGroup != null && _selectedGroup!.registers.isNotEmpty)
                DropdownButton<RegisterModel>(
                  value: _selectedRegister,
                  underline: const SizedBox(),
                  items: _selectedGroup!.registers.map((r) {
                    return DropdownMenuItem(
                      value: r,
                      child: Text('${r.displayAlias ?? "Point"}[${AppI18n.instance.t('colAddr')}:${r.address}] (${AppI18n.instance.t('currValue')}: ${r.rawValue})'),
                    );
                  }).toList(),
                  onChanged: (r) {
                    setState(() {
                      _selectedRegister = r;
                      _history.clear();
                    });
                  },
                ),
              IconButton.outlined(
                icon: const Icon(Icons.clear_all),
                tooltip: AppI18n.instance.t('clearChart'),
                onPressed: () => setState(() => _history.clear()),
              ),
            ],
          ),
        ),

        // Live stats banner
        if (_selectedRegister != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_selectedRegister!.displayAlias ?? "Point"} [${AppI18n.instance.t('colAddr')}: ${_selectedRegister!.address}]',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Text(
                  '${AppI18n.instance.t('currValue')}: ${_selectedRegister!.rawValue}',
                  style: TextStyle(fontSize: 14, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${AppI18n.instance.t('pointsCount')}: ${_history.length} / $_maxPoints', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
              ],
            ),
          ),

        // Canvas Area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 3,
              color: const Color(0xFF1E1E2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _history.isEmpty
                    ? Center(
                        child: Text(AppI18n.instance.t('noChartData'), style: const TextStyle(color: Colors.white60)),
                      )
                    : CustomPaint(
                        painter: _TrendChartPainter(_history),
                        child: Container(),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<double> values;

  _TrendChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i <= 4; i++) {
      final x = size.width * (i / 5);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    double minVal = values.reduce((a, b) => a < b ? a : b);
    double maxVal = values.reduce((a, b) => a > b ? a : b);
    if ((maxVal - minVal).abs() < 0.001) {
      maxVal += 1.0;
      minVal -= 1.0;
    }

    final double range = maxVal - minVal;
    final path = Path();
    final stepX = size.width / (values.length > 1 ? (values.length - 1) : 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final normalizedY = (values[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.8 + size.height * 0.1);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw last point dot
    final lastX = (values.length - 1) * stepX;
    final lastNormalizedY = (values.last - minVal) / range;
    final lastY = size.height - (lastNormalizedY * size.height * 0.8 + size.height * 0.1);

    final dotPaint = Paint()..color = Colors.amberAccent;
    canvas.drawCircle(Offset(lastX, lastY), 5, dotPaint);

    // Min & Max text
    final textPainterMax = TextPainter(
      text: TextSpan(text: 'Max: ${maxVal.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterMax.paint(canvas, const Offset(8, 8));

    final textPainterMin = TextPainter(
      text: TextSpan(text: 'Min: ${minVal.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainterMin.paint(canvas, Offset(8, size.height - 20));
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => true;
}
