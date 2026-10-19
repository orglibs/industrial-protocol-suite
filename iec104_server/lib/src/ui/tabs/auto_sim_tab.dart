import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../server/ease_functions.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';

class AutoSimTab extends StatefulWidget {
  final List<Iec104ConnectionConfig>? connections;
  final Iec104Server? server;

  const AutoSimTab({
    super.key,
    this.connections,
    this.server,
  });

  @override
  State<AutoSimTab> createState() => _AutoSimTabState();
}

class _AutoSimTabState extends State<AutoSimTab> {
  late List<Iec104ConnectionConfig> _internalConnections;
  Iec104ConnectionConfig? _selectedConnection;
  int _selectedCoa = 1;

  @override
  void initState() {
    super.initState();
    _initConnections();
    _syncSelection();
  }

  @override
  void didUpdateWidget(covariant AutoSimTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connections != oldWidget.connections || widget.server != oldWidget.server) {
      _initConnections();
      _syncSelection();
    }
  }

  void _initConnections() {
    if (widget.connections != null && widget.connections!.isNotEmpty) {
      _internalConnections = widget.connections!;
    } else if (widget.server != null) {
      _internalConnections = [
        Iec104ConnectionConfig(
          id: 'conn-server',
          name: 'IEC 104 Server',
          host: widget.server!.host,
          port: widget.server!.port,
          server: widget.server!,
        ),
      ];
    } else {
      _internalConnections = [];
    }
  }

  void _syncSelection() {
    if (_internalConnections.isNotEmpty) {
      if (_selectedConnection == null || !_internalConnections.contains(_selectedConnection)) {
        _selectedConnection = _internalConnections.first;
      }
      final stations = _selectedConnection?.server.stations ?? {};
      if (stations.isNotEmpty) {
        if (!stations.containsKey(_selectedCoa)) {
          _selectedCoa = stations.keys.first;
        }
      } else {
        _selectedCoa = 1;
      }
    } else {
      _selectedConnection = null;
      _selectedCoa = 1;
    }
  }

  Station? get _currentStation {
    final server = _selectedConnection?.server ?? widget.server;
    return server?.stations[_selectedCoa];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    _syncSelection();

    final station = _currentStation;
    final points = station?.pointList ?? [];
    final activeCount = points.where((p) => p.autoChangeEnabled).length;
    final server = _selectedConnection?.server ?? widget.server;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Top selector bar: Connection & Station
        if (_internalConnections.length > 1 || (server != null && server.stations.length > 1)) ...[
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_internalConnections.length > 1) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${i18n.t('tabConnections')}: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButton<Iec104ConnectionConfig>(
                        value: _internalConnections.contains(_selectedConnection) ? _selectedConnection : null,
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        items: _internalConnections.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c.displayName),
                          );
                        }).toList(),
                        onChanged: (c) {
                          if (c != null) {
                            setState(() {
                              _selectedConnection = c;
                              final stKeys = c.server.stations.keys;
                              _selectedCoa = stKeys.isNotEmpty ? stKeys.first : 1;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              if (server != null && server.stations.isNotEmpty) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("${i18n.t('coa')}: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: DropdownButton<int>(
                        value: server.stations.containsKey(_selectedCoa)
                            ? _selectedCoa
                            : server.stations.keys.first,
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        items: server.stations.values.map((s) {
                          return DropdownMenuItem(
                            value: s.commonAddress,
                            child: Text('CA: ${s.commonAddress} - ${s.displayName} (${s.points.length})'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCoa = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],

        // Controls Banner
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.auto_graph, size: 36, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t('colSim'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Active Simulations: $activeCount / ${points.length}',
                        style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      for (final p in points) {
                        p.autoChangeEnabled = true;
                      }
                    });
                  },
                  child: Text(i18n.t('startAll')),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      for (final p in points) {
                        p.autoChangeEnabled = false;
                      }
                    });
                  },
                  child: Text(i18n.t('stopAll')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Point simulation cards
        if (points.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(i18n.t('noChartData')),
            ),
          )
        else
          ...points.map((p) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Switch(
                      value: p.autoChangeEnabled,
                      onChanged: (v) => setState(() => p.autoChangeEnabled = v),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('IOA: ${p.ioa} - ${p.displayName}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text("${p.typeId.nameString} | ${i18n.t('currValue')}: ${p.displayValue}",
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<EaseType>(
                              initialValue: p.easeType,
                              decoration: InputDecoration(labelText: i18n.t('waveType'), isDense: true, border: const OutlineInputBorder()),
                              items: EaseType.values.map((e) {
                                return DropdownMenuItem(value: e, child: Text(e.description, style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => p.easeType = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: p.easeMin.toString(),
                              decoration: InputDecoration(labelText: i18n.t('waveMin'), isDense: true, border: const OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null) p.easeMin = val;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: p.easeMax.toString(),
                              decoration: InputDecoration(labelText: i18n.t('waveMax'), isDense: true, border: const OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null) p.easeMax = val;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: p.easePeriodSeconds.toString(),
                              decoration: InputDecoration(labelText: i18n.t('wavePeriod'), isDense: true, border: const OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) {
                                final val = double.tryParse(v);
                                if (val != null) p.easePeriodSeconds = val;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
