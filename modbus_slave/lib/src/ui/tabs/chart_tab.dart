import '../../i18n/app_i18n.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/register_model.dart';
import '../../models/slave_model.dart';

class ChartTab extends StatefulWidget {
  final List<ConnectionConfig> connections;

  const ChartTab({super.key, required this.connections});

  @override
  State<ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<ChartTab> {
  Timer? _sampleTimer;
  final List<double> _history = [];
  static const int _maxPoints = 120;
  bool _isPaused = false;

  ConnectionConfig? _selectedConnection;
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;
  RegisterModel? _selectedRegister;

  @override
  void initState() {
    super.initState();
    _initSelection();
    _sampleTimer = Timer.periodic(const Duration(milliseconds: 200), _sampleData);
  }

  void _initSelection() {
    if (widget.connections.isNotEmpty) {
      _selectedConnection = widget.connections.first;
      if (_selectedConnection!.slaves.isNotEmpty) {
        _selectedSlave = _selectedConnection!.slaves.first;
        if (_selectedSlave!.groups.isNotEmpty) {
          _selectedGroup = _selectedSlave!.groups.first;
          if (_selectedGroup!.registers.isNotEmpty) {
            _selectedRegister = _selectedGroup!.registers.first;
          }
        }
      }
    }
  }

  void _sampleData(Timer timer) {
    if (_isPaused || _selectedRegister == null) return;

    final val = _selectedRegister!.rawValue.toDouble();
    if (mounted) {
      setState(() {
        if (_history.length >= _maxPoints) {
          _history.removeAt(0);
        }
        _history.add(val);
      });
    }
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double minVal = 0;
    double maxVal = 100;
    if (_history.isNotEmpty) {
      minVal = _history.reduce((a, b) => a < b ? a : b);
      maxVal = _history.reduce((a, b) => a > b ? a : b);
      if ((maxVal - minVal).abs() < 1e-4) {
        minVal -= 5;
        maxVal += 5;
      }
    }

    final curVal = _selectedRegister?.rawValue ?? 0;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Selection Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Connection (width: 195, menuWidth: 320)
                      Tooltip(
                        message: _selectedConnection?.displayName ?? AppI18n.instance.t('selectConn'),
                        waitDuration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 195,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButton<ConnectionConfig>(
                            isExpanded: true,
                            menuWidth: 320,
                            menuMaxHeight: 400,
                            value: widget.connections.contains(_selectedConnection) ? _selectedConnection : null,
                            hint: Text(AppI18n.instance.t('selectConn'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: widget.connections.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Tooltip(
                                  message: c.displayName,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(c.displayName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                ),
                              );
                            }).toList(),
                            onChanged: (c) {
                              setState(() {
                                _selectedConnection = c;
                                _selectedSlave = c?.slaves.isNotEmpty == true ? c!.slaves.first : null;
                                _selectedGroup = _selectedSlave?.groups.isNotEmpty == true ? _selectedSlave!.groups.first : null;
                                _selectedRegister = _selectedGroup?.registers.isNotEmpty == true ? _selectedGroup!.registers.first : null;
                                _history.clear();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Slave (width: 175, menuWidth: 280)
                      Tooltip(
                        message: _selectedSlave != null
                            ? '${_selectedSlave!.displayName} (ID: ${_selectedSlave!.slaveId})'
                            : AppI18n.instance.t('selectSlave'),
                        waitDuration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 175,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButton<SlaveModel>(
                            isExpanded: true,
                            menuWidth: 280,
                            menuMaxHeight: 400,
                            value: _selectedConnection?.slaves.contains(_selectedSlave) == true ? _selectedSlave : null,
                            hint: Text(AppI18n.instance.t('selectSlave'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: (_selectedConnection?.slaves ?? []).map((s) {
                              final text = '${s.displayName} (ID: ${s.slaveId})';
                              return DropdownMenuItem(
                                value: s,
                                child: Tooltip(
                                  message: text,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                ),
                              );
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
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Group (width: 220, menuWidth: 340)
                      Tooltip(
                        message: _selectedGroup?.displayGroupName ?? AppI18n.instance.t('selectGroup'),
                        waitDuration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 220,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButton<RegisterGroupModel>(
                            isExpanded: true,
                            menuWidth: 340,
                            menuMaxHeight: 400,
                            value: _selectedSlave?.groups.contains(_selectedGroup) == true ? _selectedGroup : null,
                            hint: Text(AppI18n.instance.t('selectGroup'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: (_selectedSlave?.groups ?? []).map((g) {
                              final text = g.displayGroupName;
                              return DropdownMenuItem(
                                value: g,
                                child: Tooltip(
                                  message: text,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(text, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                ),
                              );
                            }).toList(),
                            onChanged: (g) {
                              setState(() {
                                _selectedGroup = g;
                                _selectedRegister = g?.registers.isNotEmpty == true ? g!.registers.first : null;
                                _history.clear();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Register (width: 210, menuWidth: 320)
                      Tooltip(
                        message: _selectedRegister != null
                            ? '${AppI18n.instance.t('colAddr')} ${_selectedRegister!.address}${_selectedRegister!.displayAlias != null ? ' - ${_selectedRegister!.displayAlias}' : ''}'
                            : AppI18n.instance.t('selectPoint'),
                        waitDuration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 210,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          alignment: Alignment.center,
                          child: DropdownButton<RegisterModel>(
                            isExpanded: true,
                            menuWidth: 320,
                            menuMaxHeight: 400,
                            value: _selectedGroup?.registers.contains(_selectedRegister) == true ? _selectedRegister : null,
                            hint: Text(AppI18n.instance.t('selectPoint'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            underline: const SizedBox(),
                            isDense: true,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: (_selectedGroup?.registers ?? []).map((r) {
                              final alias = r.displayAlias != null ? ' - ${r.displayAlias}' : '';
                              final text = '${AppI18n.instance.t('colAddr')} ${r.address}$alias';
                              return DropdownMenuItem(
                                value: r,
                                child: Tooltip(
                                  message: text,
                                  waitDuration: const Duration(milliseconds: 150),
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (r) {
                              setState(() {
                                _selectedRegister = r;
                                _history.clear();
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                        tooltip: _isPaused ? AppI18n.instance.t('resumeLog') : AppI18n.instance.t('pauseLog'),
                        onPressed: () => setState(() => _isPaused = !_isPaused),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.clear_all),
                        tooltip: AppI18n.instance.t('clearChart'),
                        onPressed: () => setState(() => _history.clear()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Current Value & Stats Cards
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppI18n.instance.t('currValue'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                curVal.toString(),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppI18n.instance.t('waveMin'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                minVal.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppI18n.instance.t('waveMax'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                maxVal.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppI18n.instance.t('refreshRate'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                '5 Hz (200ms)',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Live Curve Chart
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _history.isEmpty
                      ? Center(child: Text(AppI18n.instance.t('noChartData')))
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _LiveTrendPainter(
                            data: _history,
                            minVal: minVal,
                            maxVal: maxVal,
                            lineColor: theme.colorScheme.primary,
                            gridColor: theme.dividerColor.withOpacity(0.4),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveTrendPainter extends CustomPainter {
  final List<double> data;
  final double minVal;
  final double maxVal;
  final Color lineColor;
  final Color gridColor;

  _LiveTrendPainter({
    required this.data,
    required this.minVal,
    required this.maxVal,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    const gridLines = 5;
    for (int i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final range = maxVal - minVal;
    final span = range.abs() < 1e-4 ? 1.0 : range;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (_ChartTabState._maxPoints - 1);
    final startOffset = size.width - (data.length - 1) * stepX;

    for (int i = 0; i < data.length; i++) {
      final x = startOffset + i * stepX;
      final norm = (data[i] - minVal) / span;
      final y = size.height - (norm.clamp(0.0, 1.0) * (size.height - 24) + 12);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (data.isNotEmpty) {
      final lastX = startOffset + (data.length - 1) * stepX;
      fillPath.lineTo(lastX, size.height);
      fillPath.close();

      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);

      // Draw point on current value
      final curY = size.height - (((data.last - minVal) / span).clamp(0.0, 1.0) * (size.height - 24) + 12);
      canvas.drawCircle(Offset(lastX, curY), 5, Paint()..color = lineColor);
      canvas.drawCircle(Offset(lastX, curY), 2.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveTrendPainter oldDelegate) => true;
}
