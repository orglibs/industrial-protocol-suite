import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/dictionary_service.dart';
import '../../models/scl_parser.dart';
import '../../protocol/iec61850_client_manager.dart';

class SclToolsTab extends StatefulWidget {
  final Iec61850ClientManager manager;
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

  void _applySclToActiveConnection() {
    final engine = widget.manager.activeEngine;
    if (engine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个连接配置')),
      );
      return;
    }

    try {
      final res = SclParser.parseString(_xmlCtrl.text);
      engine.bindSclModel(res);
      engine.config.sclFilePath = _currentLoadedFile;
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SCL 模型应用成功！解析出 ${res.variables.length} 个数据属性，${res.dataSets.length} 个数据集，${res.reportControls.length} 个报告控制块。',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SCL 解析失败: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _searchDictionary() {
    final q = _dictSearchCtrl.text.trim();
    if (q.isEmpty) return;

    final dict = DictionaryService.instance;
    final sb = StringBuffer();

    // 1. LN
    final lnDesc = dict.lookupLn(q);
    if (lnDesc != null) {
      sb.writeln('【逻辑节点 LN】 $q: $lnDesc');
    }

    // 2. DO
    final doDesc = dict.lookupDo(q);
    if (doDesc != null) {
      sb.writeln('【数据对象 DO】 $q: $doDesc');
    }

    // 3. DA
    final daDesc = dict.lookupDa(q);
    if (daDesc != null) {
      sb.writeln('【数据属性 DA】 $q: $daDesc');
    }

    // 4. CDC
    final cdcDesc = dict.lookupCdc(q);
    if (cdcDesc != null) {
      sb.writeln('【公共数据类 CDC】 $q: $cdcDesc');
    }

    if (sb.isEmpty) {
      sb.writeln('未在标准 IEC 61850 字典中找到与 "$q" 匹配的条目。');
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
        // Left Column: Template Selector & Dictionary Query
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Template Library Header
                Row(
                  children: [
                    const Icon(Icons.library_books, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    const Text('标准 ICD/SCL 模板库', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '选择经典标准工程模板以离线绑定客户端数据模型:',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 10),

                // Template List
                ...List.generate(_templates.length, (i) {
                  final t = _templates[i];
                  final isSelected = _currentLoadedFile == t.filename;

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.grey[850]! : Colors.grey[300]!),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(t.desc, style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () => _loadTemplate(t.filename),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Custom Local SCL File Load
                Row(
                  children: [
                    const Icon(Icons.file_open, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text('加载本地 SCL 文件', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customPathCtrl,
                  decoration: const InputDecoration(
                    hintText: '输入外部 .icd / .cid / .scd 路径...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('加载外部文件内容'),
                  onPressed: () {
                    final path = _customPathCtrl.text.trim();
                    if (path.isNotEmpty) {
                      _loadTemplate(path);
                    }
                  },
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Standard IEC 61850 Dictionary Lookup
                Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    const Text('标准规约字典查询', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dictSearchCtrl,
                        decoration: const InputDecoration(
                          hintText: '查询 LN / DO / DA / CDC 名称 (如 MMXU, TotW, SPCSO, q)...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _searchDictionary(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchDictionary,
                    ),
                  ],
                ),
                if (_dictSearchResult.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _dictSearchResult,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right Column: XML Code Editor / Viewer & Apply Button
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Top Action Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
                  border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SCL 源码预览: ${_currentLoadedFile.isEmpty ? "未选择" : _currentLoadedFile}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('应用此 SCL 到当前连接'),
                      onPressed: _applySclToActiveConnection,
                    ),
                  ],
                ),
              ),

              // XML Text Editor
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _xmlCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
