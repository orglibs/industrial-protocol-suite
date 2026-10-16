import 'package:flutter/material.dart';
import '../../models/scl_models.dart';
import '../../models/server_variable_model.dart';
import '../../models/simulation_config.dart';
import '../../protocol/iec61850_server_manager.dart';
import '../dialogs/simulation_dialog.dart';
import '../dialogs/write_value_dialog.dart';

class DataMonitorTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const DataMonitorTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<DataMonitorTab> createState() => _DataMonitorTabState();
}

class _DataMonitorTabState extends State<DataMonitorTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _onlyMonitored = false;
  bool _onlySimulated = false;
  String _fcFilter = 'ALL';
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchText = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allVars = widget.manager.engine.allVariables;

    final filtered = allVars.where((v) {
      if (_onlyMonitored && !v.isMonitored) return false;
      if (_onlySimulated && !v.simulation.enabled) return false;
      if (_fcFilter != 'ALL' && v.fcCode != _fcFilter) return false;
      if (_searchText.isNotEmpty) {
        return v.reference.toLowerCase().contains(_searchText) ||
            v.shortRef.toLowerCase().contains(_searchText) ||
            v.doName.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              // Search Input
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '搜索变量 (如 mag, stVal)...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => _searchCtrl.clear())
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Pinned Filter
              FilterChip(
                label: const Text('仅显示关注变量'),
                selected: _onlyMonitored,
                onSelected: (val) => setState(() => _onlyMonitored = val),
              ),
              const SizedBox(width: 8),
              // Simulation Filter
              FilterChip(
                label: const Text('仅显示波形仿真中'),
                selected: _onlySimulated,
                onSelected: (val) => setState(() => _onlySimulated = val),
              ),
              const SizedBox(width: 12),
              // FC Dropdown Filter
              DropdownButton<String>(
                value: _fcFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('FC: 全部')),
                  DropdownMenuItem(value: 'ST', child: Text('FC: ST (状态)')),
                  DropdownMenuItem(value: 'MX', child: Text('FC: MX (遥测)')),
                  DropdownMenuItem(value: 'CO', child: Text('FC: CO (控制)')),
                  DropdownMenuItem(value: 'SP', child: Text('FC: SP (定值)')),
                  DropdownMenuItem(value: 'CF', child: Text('FC: CF (配置)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _fcFilter = val);
                },
              ),
              const Spacer(),
              // Global Simulation Actions
              OutlinedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 16, color: Colors.green),
                label: const Text('启动全部仿真'),
                onPressed: () {
                  for (final v in allVars) {
                    if (v.fc == FunctionalConstraint.mx) {
                      v.simulation.enabled = true;
                      if (v.simulation.waveType == EaseWaveType.none) {
                        v.simulation.waveType = EaseWaveType.sine;
                      }
                    }
                  }
                  widget.manager.simulationService.start(intervalMs: 1000);
                  widget.onDataChanged();
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.stop, size: 16, color: Colors.red),
                label: const Text('停止全部仿真'),
                onPressed: () {
                  for (final v in allVars) {
                    v.simulation.enabled = false;
                  }
                  widget.manager.simulationService.stop();
                  widget.onDataChanged();
                  setState(() {});
                },
              ),
            ],
          ),
        ),

        // Variables Table
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('无匹配变量数据', style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      headingRowHeight: 40,
                      dataRowMinHeight: 42,
                      dataRowMaxHeight: 46,
                      columns: const [
                        DataColumn(label: Text('关注', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('变量标识 (Reference)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('FC', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('类型', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('当前值 (Live Value)', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('品质状态', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('更新时间', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('波形仿真', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('操作', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((v) {
                        return DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                color: v.isMonitored ? Colors.amber : null,
                                onPressed: () {
                                  setState(() {
                                    v.isMonitored = !v.isMonitored;
                                  });
                                  widget.onDataChanged();
                                },
                              ),
                            ),
                            DataCell(
                              SelectableText(
                                v.shortRef,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                            DataCell(_fcBadge(v.fcCode)),
                            DataCell(Text(v.type.name, style: const TextStyle(fontSize: 12))),
                            DataCell(
                              v.type == IecBasicType.boolean
                                  ? Switch(
                                      value: v.value == true,
                                      onChanged: (val) {
                                        setState(() {
                                          v.value = val;
                                        });
                                        widget.onDataChanged();
                                      },
                                    )
                                  : InkWell(
                                      onTap: () => _openWriteDialog(v),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          v.displayValue,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: v.quality == 0 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  v.qualityString,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: v.quality == 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                v.timestamp.toIso8601String().substring(11, 23),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                            DataCell(
                              InkWell(
                                onTap: () => _openSimDialog(v),
                                child: v.simulation.enabled
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.waves, size: 14, color: Colors.blue),
                                            const SizedBox(width: 4),
                                            Text(
                                              v.simulation.waveType.name.toUpperCase(),
                                              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Text('-', style: TextStyle(color: Colors.grey)),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    tooltip: '写入数据',
                                    onPressed: () => _openWriteDialog(v),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.waves, size: 16),
                                    tooltip: '波形仿真',
                                    onPressed: () => _openSimDialog(v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _fcBadge(String fc) {
    Color bg = Colors.blueGrey;
    if (fc == 'ST') bg = Colors.green[700]!;
    if (fc == 'MX') bg = Colors.teal[700]!;
    if (fc == 'CO') bg = Colors.deepOrange[700]!;
    if (fc == 'SP') bg = Colors.indigo[700]!;
    if (fc == 'CF') bg = Colors.purple[700]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        fc,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _openWriteDialog(ServerVariableModel v) {
    showDialog(
      context: context,
      builder: (ctx) => WriteValueDialog(
        variable: v,
        onSaved: (variable, val, quality) {
          setState(() {
            variable.value = val;
            variable.quality = quality;
          });
          widget.onDataChanged();
        },
      ),
    );
  }

  void _openSimDialog(ServerVariableModel v) {
    showDialog(
      context: context,
      builder: (ctx) => SimulationDialog(
        variable: v,
        onSaved: (variable) {
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }
}
