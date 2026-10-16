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
    final points = _station.pointList;
    final activeCount = points.where((p) => p.autoChangeEnabled).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.server.stations.length > 1) ...[
          Row(
            children: [
              const Text('选择模拟目标从站: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: widget.server.stations.containsKey(_selectedCoa)
                    ? _selectedCoa
                    : widget.server.stations.keys.first,
                items: widget.server.stations.values.map((s) {
                  return DropdownMenuItem(
                    value: s.commonAddress,
                    child: Text('CA: ${s.commonAddress} - ${s.name} (${s.points.length}点)'),
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
                const Icon(Icons.auto_graph, size: 36, color: Colors.indigo),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('工业数据自动变化模拟 (Easing Functions)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '模拟电网运行环境下的电压波动、功率负荷变化、断路器变位，并以突发 (COT=3) 推送至 SCADA 主站。当前激活数: $activeCount',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
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
                  child: const Text('启用全部模拟'),
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
                  child: const Text('停止全部'),
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
                        Text('${p.typeId.nameString} | 当前值: ${p.displayValue}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
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
                            decoration: const InputDecoration(labelText: '曲线函数', isDense: true, border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(labelText: '最小值', isDense: true, border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(labelText: '最大值', isDense: true, border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(labelText: '周期 (秒)', isDense: true, border: OutlineInputBorder()),
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
