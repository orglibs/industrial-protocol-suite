import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../server/ease_functions.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';

class AutoSimTab extends StatefulWidget {
  final Iec104Server server;

  const AutoSimTab({super.key, required this.server});

  @override
  State<AutoSimTab> createState() => _AutoSimTabState();
}

class _AutoSimTabState extends State<AutoSimTab> {
  int _selectedCoa = 1;

  Station get _station =>
      widget.server.stations[_selectedCoa] ??
      (widget.server.stations.values.isNotEmpty
          ? widget.server.stations.values.first
          : Station.createDefault(commonAddress: 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _station.pointList;
    final activeCount = points.where((p) => p.autoChangeEnabled).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.server.stations.length > 1) ...[
          Row(
            children: [
              Text("${AppI18n.instance.t('coa')}: ", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: widget.server.stations.containsKey(_selectedCoa)
                    ? _selectedCoa
                    : widget.server.stations.keys.first,
                items: widget.server.stations.values.map((s) {
                  return DropdownMenuItem(
                    value: s.commonAddress,
                    child: Text('CA: ${s.commonAddress} - ${s.name} (${s.points.length})'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCoa = v);
                },
              ),
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
                      Text(AppI18n.instance.t('colSim'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Active Simulations: $activeCount',
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
                  child: Text(AppI18n.instance.t('startAll')),
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
                  child: Text(AppI18n.instance.t('stopAll')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Point simulation cards
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
                        Text('IOA: ${p.ioa} - ${p.name}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("${p.typeId.nameString} | ${AppI18n.instance.t('currValue')}: ${p.displayValue}",
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
                            decoration: InputDecoration(labelText: AppI18n.instance.t('waveType'), isDense: true, border: const OutlineInputBorder()),
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
                            decoration: InputDecoration(labelText: AppI18n.instance.t('waveMin'), isDense: true, border: const OutlineInputBorder()),
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
                            decoration: InputDecoration(labelText: AppI18n.instance.t('waveMax'), isDense: true, border: const OutlineInputBorder()),
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
                            decoration: InputDecoration(labelText: AppI18n.instance.t('wavePeriod'), isDense: true, border: const OutlineInputBorder()),
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
