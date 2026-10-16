import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/dictionary_service.dart';
import '../../models/scl_parser.dart';
import '../../protocol/iec61850_server_manager.dart';

class SclToolsTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const SclToolsTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<SclToolsTab> createState() => _SclToolsTabState();
}

class _SclToolsTabState extends State<SclToolsTab> {
  final TextEditingController _xmlCtrl = TextEditingController();
  final TextEditingController _customPathCtrl = TextEditingController();
  final TextEditingController _dictSearchCtrl = TextEditingController();

  String _currentLoadedFile = '';
  String _dictSearchResult = '';

  final List<({String title, String filename, String desc})> _templates = const [
    (
      title: '基础模拟量与开关量 I/O',
      filename: 'assets/examples/server_example_basic_io.icd',
      desc: '包含 GGIO 模拟量遥测 (AnIn1) 与遥信 (Ind1)，配置了 BRCB 与 URCB 报告。',
    ),
    (
      title: '可控开关控制模型 (CSWI / GGIO)',
      filename: 'assets/examples/server_example_control.icd',
      desc: '支持点控 (SPCSO1~9)，包含 Direct 与 SBO 控前选择与控后操作。',
    ),
    (
      title: 'GOOSE 保护跳闸与变位组播',
      filename: 'assets/examples/server_example_goose.icd',
      desc: '配置了 PTRC1 保护跳闸逻辑节点、dsGooseTrip 数据集与 GSEControl。',
    ),
    (
      title: 'IEC 61400-25 风力发电机模型',
      filename: 'assets/examples/server_example_61400_25.icd',
      desc: '符合国际风机标准化规约，包含转速、功率、桨距角等专业 LN 节点。',
    ),
    (
      title: '多定值区切换模型 (SGCB)',
      filename: 'assets/examples/server_example_sg.icd',
      desc: '包含多套保护定值区配置，演示运行定值区 ActSG 与编辑定值区 EditSG。',
    ),
    (
      title: '复变参数模型 (CA)',
      filename: 'assets/examples/server_example_ca.icd',
      desc: '复数测量值模型，包含相角、幅值等工程参数。',
    ),
    (
      title: '死区与变化上送 (Deadband)',
      filename: 'assets/examples/server_example_deadband.icd',
      desc: '遥测死区过滤与积分周期变化上送配置。',
    ),
    (
      title: '综合变电站 IED 模型',
      filename: 'assets/examples/server_example_simple.icd',
      desc: '包含完整的测量与开关综合逻辑节点树。',
    ),
    (
      title: '数据替代模型 (Substitution)',
      filename: 'assets/examples/server_example_substitution.icd',
      desc: '演示人工置数与自动采集切换的 SubVal / SubQ 替代功能。',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplate(_templates.first.filename);
  }

  @override
  void dispose() {
    _xmlCtrl.dispose();
    _customPathCtrl.dispose();
    _dictSearchCtrl.dispose();
    super.dispose();
  }

  void _loadTemplate(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        final content = f.readAsStringSync();
        _xmlCtrl.text = content;
        _currentLoadedFile = path;
        setState(() {});
      }
    } catch (_) {}
  }

  void _applyModel() {
    try {
      final res = SclParser.parse(_xmlCtrl.text);
      widget.manager.loadScl(res);
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已成功解析并应用 SCL 模型！IED: ${res.iedName}，变量数: ${res.variables.length}'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SCL 解析失败: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _searchDictionary(String query) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) {
      setState(() => _dictSearchResult = '');
      return;
    }

    final dict = DictionaryService.instance;
    final cdc = dict.getCdc(q);
    final ln = dict.getLogicalNode(q);
    final doItem = dict.getDataObject(q);
    final da = dict.getDataAttribute(q);

    final sb = StringBuffer();
    if (cdc != null) sb.writeln('[公共数据类 CDC] ${cdc.name}: ${cdc.display}');
    if (ln != null) sb.writeln('[逻辑节点 LN] ${ln.name}: ${ln.display}');
    if (doItem != null) sb.writeln('[数据对象 DO] ${doItem.name}: ${doItem.display}');
    if (da != null) sb.writeln('[数据属性 DA] ${da.name}: ${da.display}');

    if (sb.isEmpty) {
      sb.writeln('未在 IEC 61850 标准元数据字典中检索到 "$query"。');
    }

    setState(() {
      _dictSearchResult = sb.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Left Column: Template Library & Dictionary Search
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('内置行业标准 SCL 模板库', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ..._templates.map((tpl) {
                  final isLoaded = _currentLoadedFile == tpl.filename;
                  return Card(
                    elevation: isLoaded ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isLoaded
                          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(tpl.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(tpl.desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.preview, size: 14),
                                label: const Text('查看代码', style: TextStyle(fontSize: 11)),
                                onPressed: () => _loadTemplate(tpl.filename),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.play_arrow, size: 14),
                                label: const Text('一键应用', style: TextStyle(fontSize: 11)),
                                onPressed: () {
                                  _loadTemplate(tpl.filename);
                                  _applyModel();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 24),
                // Dictionary Lookup
                const Text('IEC 61850 标准字典速查', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _dictSearchCtrl,
                  decoration: InputDecoration(
                    hintText: '输入 CDC / LN / DO / DA (如 MMXU, Pos, stVal)...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: () => _searchDictionary(_dictSearchCtrl.text),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onSubmitted: _searchDictionary,
                ),
                if (_dictSearchResult.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(_dictSearchResult, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right Column: SCL XML Code Editor & Apply
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SCL (ICD/CID/SCD) 文件源代码 [$_currentLoadedFile]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('解析并更新当前服务器模型'),
                      onPressed: _applyModel,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _xmlCtrl,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
