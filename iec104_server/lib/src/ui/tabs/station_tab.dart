import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';
import '../dialogs/add_point_dialog.dart';
import '../dialogs/batch_init_dialog.dart';
import '../dialogs/point_edit_value_dialog.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/edit_station_dialog.dart';

class StationTab extends StatefulWidget {
  final Iec104Server server;

  const StationTab({super.key, required this.server});

  @override
  State<StationTab> createState() => _StationTabState();
}

class _StationTabState extends State<StationTab> {
  int _selectedCoa = 1;
  String _filterType = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.server.stations.isNotEmpty) {
      _selectedCoa = widget.server.stations.keys.first;
    }
    // Listen to server point updates to rebuild UI on live values
    widget.server.pointUpdateStream.listen((_) {
      if (mounted) setState(() {});
    });
    // Listen to station list changes
    widget.server.stationsStream.listen((_) {
      if (mounted) {
        setState(() {
          if (!widget.server.stations.containsKey(_selectedCoa)) {
            _selectedCoa = widget.server.stations.keys.firstOrNull ?? 1;
          }
        });
      }
    });
  }

  Station? get _currentStation => widget.server.stations[_selectedCoa];

  List<StationPoint> get _filteredPoints {
    final station = _currentStation;
    if (station == null) return [];

    return station.pointList.where((p) {
      // Type filter
      if (_filterType == 'SP') {
        if (p.typeId != AsduTypeId.mSpNa1 && p.typeId != AsduTypeId.mSpTb1) return false;
      } else if (_filterType == 'DP') {
        if (p.typeId != AsduTypeId.mDpNa1 && p.typeId != AsduTypeId.mDpTb1) return false;
      } else if (_filterType == 'ME') {
        if (p.typeId != AsduTypeId.mMeNa1 &&
            p.typeId != AsduTypeId.mMeNb1 &&
            p.typeId != AsduTypeId.mMeNc1 &&
            p.typeId != AsduTypeId.mMeTd1 &&
            p.typeId != AsduTypeId.mMeTe1 &&
            p.typeId != AsduTypeId.mMeTf1) {
          return false;
        }
      } else if (_filterType == 'IT') {
        if (p.typeId != AsduTypeId.mItNa1 && p.typeId != AsduTypeId.mItTb1) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchIoa = p.ioa.toString().contains(q) ||
            '0x${p.ioa.toRadixString(16).toLowerCase()}'.contains(q);
        final matchName = p.name.toLowerCase().contains(q);
        if (!matchIoa && !matchName) return false;
      }

      return true;
    }).toList();
  }

  void _showEditDialog(StationPoint point) {
    showDialog(
      context: context,
      builder: (context) => PointEditValueDialog(
        point: point,
        onSave: (newVal, quality) {
          widget.server.updatePointValue(
            _selectedCoa,
            point.ioa,
            newVal,
            quality: quality,
            triggerSpontaneous: true,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('点位 ${point.name} [IOA: ${point.ioa}] 已更新为: $newVal，并突发推送(COT=3)'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final station = _currentStation;
    final points = _filteredPoints;

    return Column(
      children: [
        // Substation bar & Action buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              const Text('当前从站 (COA):', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<int>(
                  value: widget.server.stations.containsKey(_selectedCoa)
                      ? _selectedCoa
                      : (widget.server.stations.keys.firstOrNull ?? 1),
                  underline: const SizedBox(),
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
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('增加从站'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AddStationDialog(
                      server: widget.server,
                      onAdded: (newCa) => setState(() => _selectedCoa = newCa),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              if (station != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('管理从站'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => EditStationDialog(
                        server: widget.server,
                        station: station,
                        onStationChanged: (newCa) => setState(() => _selectedCoa = newCa),
                        onStationDeleted: () {
                          setState(() {
                            _selectedCoa = widget.server.stations.keys.firstOrNull ?? 1;
                          });
                        },
                      ),
                    );
                  },
                ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加点位'),
                onPressed: station == null
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => AddPointDialog(
                            station: station,
                            onAdd: (newPoint) {
                              setState(() => station.addPoint(newPoint));
                            },
                          ),
                        );
                      },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('批量生成'),
                onPressed: station == null
                    ? null
                    : () {
                        showDialog(
                          context: context,
                          builder: (context) => BatchInitDialog(
                            station: station,
                            onGenerate: ({required count, required prefix, required startIoa, required typeId}) {
                              setState(() {
                                station.batchGeneratePoints(
                                  typeId: typeId,
                                  startIoa: startIoa,
                                  count: count,
                                  prefix: prefix,
                                );
                              });
                            },
                          ),
                        );
                      },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重置示例数据'),
                onPressed: () {
                  setState(() {
                    widget.server.stations[_selectedCoa] = Station.createDefault(
                      commonAddress: _selectedCoa,
                      name: station?.name ?? '110kV 变电站 #1',
                    );
                  });
                },
              ),
            ],
          ),
        ),

        // Filter & Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('全部'),
                    selected: _filterType == 'ALL',
                    onSelected: (_) => setState(() => _filterType = 'ALL'),
                  ),
                  ChoiceChip(
                    label: const Text('单点遥信 (Type 1/30)'),
                    selected: _filterType == 'SP',
                    onSelected: (_) => setState(() => _filterType = 'SP'),
                  ),
                  ChoiceChip(
                    label: const Text('双点遥信 (Type 3/31)'),
                    selected: _filterType == 'DP',
                    onSelected: (_) => setState(() => _filterType = 'DP'),
                  ),
                  ChoiceChip(
                    label: const Text('遥测模拟量 (Type 9/11/13)'),
                    selected: _filterType == 'ME',
                    onSelected: (_) => setState(() => _filterType = 'ME'),
                  ),
                  ChoiceChip(
                    label: const Text('电能量遥脉 (Type 15/37)'),
                    selected: _filterType == 'IT',
                    onSelected: (_) => setState(() => _filterType = 'IT'),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索 IOA 或点位名称...',
                    prefixIcon: Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                ),
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: points.isEmpty
              ? const Center(child: Text('暂无匹配的点位'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('IOA (十进制/十六进制)')),
                        DataColumn(label: Text('ASDU 协议类型')),
                        DataColumn(label: Text('点位名称')),
                        DataColumn(label: Text('实时数值 (点击修改)')),
                        DataColumn(label: Text('品质标志')),
                        DataColumn(label: Text('自动变化模拟')),
                        DataColumn(label: Text('操作')),
                      ],
                      rows: points.map((p) {
                        final isSingle = p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1;
                        final hexIoa = '0x${p.ioa.toRadixString(16).padLeft(6, '0').toUpperCase()}';

                        return DataRow(cells: [
                          DataCell(Text('${p.ioa} ($hexIoa)', style: const TextStyle(fontFamily: 'monospace'))),
                          DataCell(Text('${p.typeId.nameString} [${p.typeId.id}]')),
                          DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(
                            InkWell(
                              onTap: () => _showEditDialog(p),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(
                                  p.displayValue,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              p.quality.summary,
                              style: TextStyle(
                                color: p.quality.invalid ? Colors.red : Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: p.autoChangeEnabled,
                                  onChanged: (v) {
                                    setState(() => p.autoChangeEnabled = v);
                                  },
                                ),
                                if (p.autoChangeEnabled)
                                  Text(
                                    p.easeType.name,
                                    style: TextStyle(fontSize: 11, color: Colors.indigo.shade700),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSingle)
                                  IconButton(
                                    icon: Icon(p.value == true ? Icons.toggle_on : Icons.toggle_off,
                                        color: p.value == true ? Colors.green : Colors.grey),
                                    tooltip: '分/合快速切换',
                                    onPressed: () {
                                      widget.server.updatePointValue(
                                        _selectedCoa,
                                        p.ioa,
                                        !(p.value == true),
                                        triggerSpontaneous: true,
                                      );
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.send, color: Colors.blue, size: 20),
                                  tooltip: '突发发送 (COT=3 Spontaneous)',
                                  onPressed: () {
                                    widget.server.broadcastSpontaneous(p, _selectedCoa);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('已向所有客户端突发推送点位 ${p.name} [COT=3]'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                                  tooltip: '编辑点位数据',
                                  onPressed: () => _showEditDialog(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: '删除点位',
                                  onPressed: () {
                                    setState(() => station?.removePoint(p.ioa));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
