import 'package:flutter/material.dart';
import '../../models/client_variable_model.dart';
import '../../models/dictionary_service.dart';
import '../../protocol/iec61850_client_manager.dart';
import '../dialogs/control_operation_dialog.dart';
import '../dialogs/write_variable_dialog.dart';

class ModelExplorerTab extends StatefulWidget {
  final Iec61850ClientManager manager;
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
  ClientVariableModel? _selectedVariable;
  String _filterText = '';
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filterText = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _discoverOnline() async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接到 IEC 61850 服务端后再执行在线模型发现')),
      );
      return;
    }

    setState(() => _isDiscovering = true);
    try {
      final ok = await engine.discoverOnlineModel();
      if (ok && mounted) {
        widget.onDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('在线模型发现成功！已加载 ${engine.allVariables.length} 个数据属性。')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final allVars = engine?.allVariables ?? [];

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
                // Top Search Bar & Online Discover Button
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: _isDiscovering
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.travel_explore, size: 18),
                        label: const Text('在线发现'),
                        onPressed: _isDiscovering ? null : _discoverOnline,
                      ),
                    ],
                  ),
                ),
                // Header Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.device_hub, size: 16, color: Theme.of(context).colorScheme.primary),
                      Expanded(
                        child: Text(
                          'IED: ${engine?.scl?.iedName ?? "已连接测控装置"} | 总变量: ${allVars.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('匹配: ${filteredVars.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Variables List
                Expanded(
                  child: filteredVars.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.device_unknown, size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              const Text('当前连接无数据测点', style: TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.travel_explore),
                                label: const Text('执行 MMS 在线模型发现 (GetNameList)'),
                                onPressed: _discoverOnline,
                              ),
                            ],
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
                                  if (v.isControllable) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('可控', style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.refresh, size: 16),
                                tooltip: '单点读取',
                                onPressed: () async {
                                  await engine?.readVariable(v);
                                  setState(() {});
                                  widget.onDataChanged();
                                },
                              ),
                              onTap: () {
                                setState(() => _selectedVariable = v);
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
              ? const Center(child: Text('在左侧选择一个数据属性查看详情、实时读取或执行控制', style: TextStyle(color: Colors.grey)))
              : _buildInspectorPanel(_selectedVariable!),
        ),
      ],
    );
  }

  Widget _buildInspectorPanel(ClientVariableModel v) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final dict = DictionaryService.instance;
    final lnDesc = dict.getLogicalNode(v.lnName.replaceAll(RegExp(r'\d+'), ''));
    final doDesc = dict.getDataObject(v.doName);
    final daDesc = dict.getDataAttribute(v.daName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  setState(() => v.isMonitored = !v.isMonitored);
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

          // Live Value & Operations Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('实时采集状态与控制操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('采集值 (Value): ', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('单点读取'),
                        onPressed: () async {
                          await engine?.readVariable(v);
                          setState(() {});
                          widget.onDataChanged();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('写入值'),
                        onPressed: () => _openWriteDialog(v),
                      ),
                      if (v.isControllable) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange[700]),
                          icon: const Icon(Icons.power_settings_new, size: 16),
                          label: const Text('遥控操作 (Control)'),
                          onPressed: () => _openControlDialog(v),
                        ),
                      ],
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

  void _openWriteDialog(ClientVariableModel v) {
    final engine = widget.manager.activeEngine;
    showDialog(
      context: context,
      builder: (ctx) => WriteVariableDialog(
        variable: v,
        onConfirm: (val) async {
          await engine?.writeVariable(v, val);
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }

  void _openControlDialog(ClientVariableModel v) {
    final engine = widget.manager.activeEngine;
    if (engine == null) return;
    showDialog(
      context: context,
      builder: (ctx) => ControlOperationDialog(
        variable: v,
        onOperate: (variable, val, {bool isSbo = false}) async {
          final res = await engine.operateControl(variable, val, isSbo: isSbo);
          setState(() {});
          widget.onDataChanged();
          return res;
        },
      ),
    );
  }
}
