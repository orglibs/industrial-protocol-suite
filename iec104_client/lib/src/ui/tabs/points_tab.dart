import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../protocol/asdu.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/edit_station_dialog.dart';
import '../dialogs/add_point_dialog.dart';
import '../dialogs/batch_add_points_dialog.dart';
import '../dialogs/edit_point_dialog.dart';
import '../dialogs/station_import_export_dialog.dart';

class PointsTab extends StatefulWidget {
  final Iec104Client client;

  const PointsTab({super.key, required this.client});

  @override
  State<PointsTab> createState() => _PointsTabState();
}

class _PointsTabState extends State<PointsTab> {
  int _selectedCa = 1;
  String _selectedCategory = '全部';
  String _searchQuery = '';
  StreamSubscription<ClientPointModel>? _pointSub;
  StreamSubscription<List<ClientStationModel>>? _stationSub;

  final List<String> _categories = [
    '全部',
    '单点遥信 (YX)',
    '双点遥信 (YX)',
    '短浮点遥测 (YC)',
    '归一化遥测 (YC)',
    '标度化遥测 (YC)',
    '电能量脉冲 (YM)',
    '变压器档位 (ST)',
    '二进制串 (BO)',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.client.stations.isNotEmpty) {
      _selectedCa = widget.client.stations.keys.first;
    }

    _pointSub = widget.client.pointUpdateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _stationSub = widget.client.stationsStream.listen((stations) {
      if (mounted) {
        setState(() {
          if (!widget.client.stations.containsKey(_selectedCa)) {
            _selectedCa = widget.client.stations.keys.firstOrNull ?? 1;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pointSub?.cancel();
    _stationSub?.cancel();
    super.dispose();
  }

  void _openAddStationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddStationDialog(
        client: widget.client,
        onAdded: (newCa) {
          setState(() => _selectedCa = newCa);
        },
      ),
    );
  }

  void _openEditStationDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => EditStationDialog(
        client: widget.client,
        station: station,
        onStationChanged: (newCa) {
          setState(() => _selectedCa = newCa);
        },
        onStationDeleted: () {
          setState(() {
            _selectedCa = widget.client.stations.keys.firstOrNull ?? 1;
          });
        },
      ),
    );
  }

  void _openAddPointDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => AddPointDialog(
        station: station,
        onAdded: (p) => setState(() {}),
      ),
    );
  }

  void _openBatchAddPointsDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => BatchAddPointsDialog(
        station: station,
        onGenerated: () => setState(() {}),
      ),
    );
  }

  void _openEditPointDialog(ClientStationModel station, ClientPointModel point) {
    showDialog(
      context: context,
      builder: (ctx) => EditPointDialog(
        station: station,
        point: point,
        onUpdated: () => setState(() {}),
        onDeleted: () => setState(() {}),
      ),
    );
  }

  void _openImportExportDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => StationImportExportDialog(
        client: widget.client,
        currentStation: station,
        onImported: () => setState(() {}),
      ),
    );
  }

  void _confirmClearStation(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空站内点号'),
        content: Text('确定要清空从站【${station.name}】下的所有 ${station.points.length} 个点号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => station.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已清空从站 [CA=${station.commonAddress}] 的所有点号')),
              );
            },
            child: const Text('确认清空'),
          ),
        ],
      ),
    );
  }

  void _quickRemoteControl(ClientPointModel p) {
    if (p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1) {
      final currentVal = p.value == true;
      final targetVal = !currentVal;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('单命令遥控 (C_SC_NA_1) - IOA: ${p.ioa}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('点位名称: ${p.name}'),
              Text('当前状态: ${p.displayValue}'),
              const SizedBox(height: 12),
              Text(
                '目标状态: ${targetVal ? "1 (合/ON)" : "0 (分/OFF)"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              const Text('标准两步遥控：可选择先“预置(Select)”或直接“执行(Execute)”：'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            OutlinedButton(
              onPressed: () {
                widget.client.sendSingleCommand(
                  ca: p.commonAddress,
                  ioa: p.ioa,
                  value: targetVal,
                  select: true,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已下发预置选择: IOA=${p.ioa}')),
                );
              },
              child: const Text('预置选择 (Select)'),
            ),
            ElevatedButton(
              onPressed: () {
                widget.client.sendSingleCommand(
                  ca: p.commonAddress,
                  ioa: p.ioa,
                  value: targetVal,
                  select: false,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已下发直接执行: IOA=${p.ioa}')),
                );
              },
              child: const Text('直接执行 (Execute)'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.client;
    final availableCas = c.stations.keys.toList()..sort();
    if (availableCas.isNotEmpty && !availableCas.contains(_selectedCa)) {
      _selectedCa = availableCas.first;
    }

    final st = c.getStation(_selectedCa);
    var points = st.pointList;

    // Filter by category
    if (_selectedCategory != '全部') {
      points = points.where((p) => p.typeCategory == _selectedCategory).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      points = points.where((p) =>
          p.ioa.toString().contains(q) ||
          '0x${p.ioa.toRadixString(16).toLowerCase()}'.contains(q) ||
          p.name.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Top Toolbar: Station Management & Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Station selector
              const Text('当前从站 (COA):', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<int>(
                  value: availableCas.contains(_selectedCa) ? _selectedCa : (availableCas.isNotEmpty ? availableCas.first : 1),
                  underline: const SizedBox(),
                  items: availableCas.map((ca) {
                    return DropdownMenuItem(
                      value: ca,
                      child: Text('CA=$ca - ${c.stations[ca]?.name ?? "变电站"} (${c.stations[ca]?.points.length ?? 0}点)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCa = val);
                  },
                ),
              ),

              // Station action buttons
              OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('增加从站'),
                onPressed: _openAddStationDialog,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: const Text('管理从站'),
                onPressed: () => _openEditStationDialog(st),
              ),

              const SizedBox(width: 8),
              // Points actions
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('增加点号'),
                onPressed: () => _openAddPointDialog(st),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.playlist_add, size: 16),
                label: const Text('批量生成点号'),
                onPressed: () => _openBatchAddPointsDialog(st),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.import_export, size: 16),
                label: const Text('导入/导出点表'),
                onPressed: () => _openImportExportDialog(st),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                label: const Text('清空点位', style: TextStyle(color: Colors.red)),
                onPressed: st.points.isNotEmpty ? () => _confirmClearStation(st) : null,
              ),
            ],
          ),
        ),

        // Filter & Search toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Category filter
              const Text('类型筛选: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox(),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Search
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜索 IOA (十进制/十六进制) 或点位名称...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('单点刷新 (Read)'),
                onPressed: c.state == ClientConnectionState.active
                    ? () {
                        if (points.isNotEmpty) {
                          c.sendReadCommand(ca: _selectedCa, ioa: points.first.ioa);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已下发读取命令 (C_RD_NA_1): IOA=${points.first.ioa}')),
                          );
                        }
                      }
                    : null,
              ),
            ],
          ),
        ),

        // Data Table / List
        Expanded(
          child: points.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        '当前从站 [CA=$_selectedCa] 暂无点位数据',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '您可以点击上方【增加点号】、【批量生成点号】进行配置，\n或在【连接】页面点击【下发总召唤】由服务端自动上送入库',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('添加点号'),
                            onPressed: () => _openAddPointDialog(st),
                          ),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('批量生成点号'),
                            onPressed: () => _openBatchAddPointsDialog(st),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final p = points[idx];
                    final isSwitch = p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isSwitch
                            ? (p.value == true ? Colors.green.shade100 : Colors.red.shade100)
                            : Colors.blue.shade100,
                        child: Text(
                          isSwitch ? (p.value == true ? '合' : '分') : '测',
                          style: TextStyle(
                            color: isSwitch
                                ? (p.value == true ? Colors.green.shade900 : Colors.red.shade900)
                                : Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'IOA: ${p.ioa}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            '[${p.typeCategory}]',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text('更新时间: ${p.lastUpdated.toIso8601String().substring(11, 23)}'),
                          const SizedBox(width: 12),
                          Text('刷新次数: ${p.updateCount}'),
                          if (p.quality != null && p.quality!.invalid) ...[
                            const SizedBox(width: 8),
                            const Text('[无效IV]', style: TextStyle(color: Colors.red)),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSwitch
                                  ? (p.value == true ? Colors.green.shade50 : Colors.red.shade50)
                                  : Colors.blue.shade50,
                              border: Border.all(
                                color: isSwitch
                                    ? (p.value == true ? Colors.green.shade400 : Colors.red.shade400)
                                    : Colors.blue.shade400,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.displayValue,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSwitch
                                    ? (p.value == true ? Colors.green.shade900 : Colors.red.shade900)
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                          if (isSwitch) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.touch_app, color: Colors.blue),
                              tooltip: '快捷遥控单命令',
                              onPressed: () => _quickRemoteControl(p),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: '读取该点位 (C_RD_NA_1)',
                            onPressed: c.state == ClientConnectionState.active
                                ? () {
                                    c.sendReadCommand(ca: _selectedCa, ioa: p.ioa);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('已下发读命令: IOA=${p.ioa}')),
                                    );
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: '编辑/删除点号',
                            onPressed: () => _openEditPointDialog(st, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
