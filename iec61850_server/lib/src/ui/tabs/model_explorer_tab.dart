import 'package:flutter/material.dart';
import '../../models/dictionary_service.dart';
import '../../models/server_variable_model.dart';
import '../../protocol/iec61850_server_manager.dart';
import '../dialogs/simulation_dialog.dart';
import '../dialogs/write_value_dialog.dart';

class ModelExplorerTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const ModelExplorerTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<ModelExplorerTab> createState() => _ModelExplorerTabState();
}

class _ModelExplorerTabState extends State<ModelExplorerTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  ServerVariableModel? _selectedVariable;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _filterText = _searchCtrl.text.trim().toLowerCase();
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
    final scl = widget.manager.engine.scl;
    final allVars = widget.manager.engine.allVariables;

    final filteredVars = _filterText.isEmpty
        ? allVars
        : allVars.where((v) =>
            v.reference.toLowerCase().contains(_filterText) ||
            v.shortRef.toLowerCase().contains(_filterText) ||
            v.lnName.toLowerCase().contains(_filterText) ||
            v.doName.toLowerCase().contains(_filterText)).toList();

    return Row(
      children: [
        // Left Column: SCL Tree & Variable List
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: '搜索逻辑节点 / 数据对象 (如 GGIO, CSWI, stVal)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _filterText.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                // Header Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.device_hub, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'IED: ${scl?.iedName ?? "未加载"} | 总变量: ${allVars.length}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('匹配: ${filteredVars.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Variables List View
                Expanded(
                  child: filteredVars.isEmpty
                      ? Center(
                          child: Text(
                            scl == null ? '尚未加载 SCL 模型文件' : '无匹配变量',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredVars.length,
                          itemBuilder: (context, index) {
                            final v = filteredVars[index];
                            final isSelected = _selectedVariable?.reference == v.reference;

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              title: Row(
                                children: [
                                  _fcBadge(v.fcCode),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${v.ldInst}/${v.lnName}.${v.doName}.${v.daName}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    '${v.type.name}  |  值: ${v.displayValue}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                  if (v.simulation.enabled) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('波形中', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 16),
                                tooltip: '写入数值',
                                onPressed: () => _openWriteDialog(v),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedVariable = v;
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Inspector Details Panel
        Expanded(
          flex: 6,
          child: _selectedVariable == null
              ? const Center(
                  child: Text('在左侧选择一个数据属性 (Data Attribute) 查看属性详情与字典', style: TextStyle(color: Colors.grey)),
                )
              : _buildInspectorPanel(_selectedVariable!),
        ),
      ],
    );
  }

  Widget _buildInspectorPanel(ServerVariableModel v) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dict = DictionaryService.instance;
    final lnDesc = dict.getLogicalNode(v.lnName.replaceAll(RegExp(r'\d+'), ''));
    final doDesc = dict.getDataObject(v.doName);
    final daDesc = dict.getDataAttribute(v.daName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _fcBadge(v.fcCode),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v.shortRef,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border),
                color: v.isMonitored ? Colors.amber : null,
                tooltip: v.isMonitored ? '已加入数据监视表' : '加入数据监视表',
                onPressed: () {
                  setState(() {
                    v.isMonitored = !v.isMonitored;
                  });
                  widget.onDataChanged();
                },
              ),
            ],
          ),
          Text(
            'MMS Reference: ${v.reference}',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Live Value & Quick Edit Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('实时运行数据', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('当前值 (Value): ', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        v.displayValue,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('写入值'),
                        onPressed: () => _openWriteDialog(v),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.waves, size: 16),
                        label: const Text('仿真波形'),
                        onPressed: () => _openSimDialog(v),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('品质状态 (Quality)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.qualityString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('更新时间 (Timestamp)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.timestamp.toIso8601String().substring(11, 23),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('基础数据类型', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.type.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Standard Metadata Dictionary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.library_books, size: 18),
                      SizedBox(width: 8),
                      Text('IEC 61850 标准元数据字典解释', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dictRow('逻辑节点 (LN)', v.lnName, lnDesc?.display),
                  _dictRow('数据对象 (DO)', v.doName, doDesc?.display),
                  _dictRow('数据属性 (DA)', v.daName, daDesc?.display),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictRow(String title, String code, String? explanation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation ?? '无内置说明',
              style: TextStyle(fontSize: 12, color: explanation != null ? null : Colors.grey),
            ),
          ),
        ],
      ),
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
