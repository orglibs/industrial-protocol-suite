import 'package:flutter/material.dart';
import '../../models/connection_config.dart';

class CreateConnectionDialog extends StatefulWidget {
  final ConnectionConfig? initialConfig;
  final void Function(ConnectionConfig config) onSaved;

  const CreateConnectionDialog({
    super.key,
    this.initialConfig,
    required this.onSaved,
  });

  @override
  State<CreateConnectionDialog> createState() => _CreateConnectionDialogState();
}

class _CreateConnectionDialogState extends State<CreateConnectionDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _localTsapCtrl;
  late TextEditingController _remoteTsapCtrl;
  late bool _autoConnect;
  String? _selectedTemplate;

  final List<({String title, String path})> _templates = const [
    (title: 'server_example_basic_io.icd (基础 I/O 测控)', path: 'assets/examples/server_example_basic_io.icd'),
    (title: 'server_example_control.icd (断路器/隔离开关控制)', path: 'assets/examples/server_example_control.icd'),
    (title: 'server_example_goose.icd (GOOSE 保护跳闸组播)', path: 'assets/examples/server_example_goose.icd'),
    (title: 'server_example_61400_25.icd (风力发电机标准)', path: 'assets/examples/server_example_61400_25.icd'),
    (title: 'server_example_sg.icd (多定值区切换模型)', path: 'assets/examples/server_example_sg.icd'),
    (title: 'server_example_simple.icd (综合变电站模型)', path: 'assets/examples/server_example_simple.icd'),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameCtrl = TextEditingController(text: c?.name ?? 'IEC 61850 服务端连接');
    _ipCtrl = TextEditingController(text: c?.ip ?? '127.0.0.1');
    _portCtrl = TextEditingController(text: (c?.port ?? 102).toString());
    _localTsapCtrl = TextEditingController(text: '0x${(c?.localTsap ?? 0x0001).toRadixString(16).padLeft(4, '0')}');
    _remoteTsapCtrl = TextEditingController(text: '0x${(c?.remoteTsap ?? 0x0001).toRadixString(16).padLeft(4, '0')}');
    _autoConnect = c?.autoConnect ?? false;
    final initialPath = c?.boundSclPath;
    if (initialPath != null && initialPath.isNotEmpty) {
      if (_templates.any((t) => t.path == initialPath)) {
        _selectedTemplate = initialPath;
      } else {
        final match = _templates.where((t) => t.title.contains(initialPath) || t.path.contains(initialPath)).firstOrNull;
        _selectedTemplate = match?.path ?? initialPath;
      }
    } else {
      _selectedTemplate = _templates.first.path;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _localTsapCtrl.dispose();
    _remoteTsapCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final id = widget.initialConfig?.id ?? 'conn_${DateTime.now().millisecondsSinceEpoch}';
    final port = int.tryParse(_portCtrl.text.trim()) ?? 102;
    int localTsap = 0x0001;
    int remoteTsap = 0x0001;

    try {
      final lStr = _localTsapCtrl.text.replaceAll('0x', '').replaceAll('0X', '');
      localTsap = int.parse(lStr, radix: 16);
    } catch (_) {}

    try {
      final rStr = _remoteTsapCtrl.text.replaceAll('0x', '').replaceAll('0X', '');
      remoteTsap = int.parse(rStr, radix: 16);
    } catch (_) {}

    final cfg = ConnectionConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      ip: _ipCtrl.text.trim(),
      port: port,
      localTsap: localTsap,
      remoteTsap: remoteTsap,
      boundSclPath: _selectedTemplate,
      autoConnect: _autoConnect,
    );

    widget.onSaved(cfg);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialConfig != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add_link),
          const SizedBox(width: 8),
          Text(isEdit ? '编辑 IEC 61850 连接' : '新建 IEC 61850 服务端连接'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '连接别名 (Connection Alias)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipCtrl,
                      decoration: const InputDecoration(
                        labelText: '远程服务器 IP 地址',
                        hintText: '127.0.0.1 或 192.168.1.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'TCP 端口',
                        hintText: '102 (或 10102)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _localTsapCtrl,
                      decoration: const InputDecoration(
                        labelText: '本地 TSAP (Local TSAP)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _remoteTsapCtrl,
                      decoration: const InputDecoration(
                        labelText: '远端 TSAP (Remote TSAP)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.tag),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _selectedTemplate,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '关联离线 SCL / ICD 模型 (选填)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('不关联离线文件 (仅使用在线 GetNameList 发现)'),
                  ),
                  ..._templates.map((t) {
                    return DropdownMenuItem<String?>(
                      value: t.path,
                      child: Text(t.title, overflow: TextOverflow.ellipsis),
                    );
                  }),
                  if (_selectedTemplate != null && !_templates.any((t) => t.path == _selectedTemplate))
                    DropdownMenuItem<String?>(
                      value: _selectedTemplate,
                      child: Text('模型: $_selectedTemplate', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (val) {
                  setState(() => _selectedTemplate = val);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启动软件时自动连接 (Auto Connect)'),
                value: _autoConnect,
                onChanged: (val) => setState(() => _autoConnect = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(isEdit ? '保存更改' : '创建连接'),
          onPressed: _save,
        ),
      ],
    );
  }
}
