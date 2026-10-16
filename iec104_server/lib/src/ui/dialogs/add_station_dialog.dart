import 'package:flutter/material.dart';
import '../../server/iec104_server.dart';

class AddStationDialog extends StatefulWidget {
  final Iec104Server server;
  final ValueChanged<int>? onAdded;

  const AddStationDialog({
    super.key,
    required this.server,
    this.onAdded,
  });

  @override
  State<AddStationDialog> createState() => _AddStationDialogState();
}

class _AddStationDialogState extends State<AddStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _caCtrl;
  late TextEditingController _nameCtrl;
  String _selectedTemplate = 'distribution';

  @override
  void initState() {
    super.initState();
    int nextCa = 1;
    while (widget.server.stations.containsKey(nextCa)) {
      nextCa++;
    }
    _caCtrl = TextEditingController(text: nextCa.toString());
    _nameCtrl = TextEditingController(text: '变电站间隔 #$nextCa');
  }

  @override
  void dispose() {
    _caCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('增加从站 (Add Station / RTU)'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '在 IEC 104 服务端中新增一个逻辑从站设备（公共地址 COA），主站可单独向该 COA 下发总召唤和遥控指令。',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _caCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '从站公共地址 (COA / Common Address)',
                  helperText: '范围: 1 ~ 65535 (全局唯一)',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final v = int.tryParse(val ?? '');
                  if (v == null || v < 1 || v > 65535) {
                    return '请输入 1 ~ 65535 之间的有效整数';
                  }
                  if (widget.server.stations.containsKey(v)) {
                    return '从站公共地址 (COA=$v) 已存在，请使用其他地址';
                  }
                  return null;
                },
                onChanged: (val) {
                  final v = int.tryParse(val);
                  if (v != null && (_nameCtrl.text.isEmpty || _nameCtrl.text.startsWith('变电站间隔 #'))) {
                    _nameCtrl.text = '变电站间隔 #$v';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '从站名称 / 设备别名 (Alias)',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '从站名称不能为空';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTemplate,
                decoration: const InputDecoration(
                  labelText: '初始点表模板 (Point Template)',
                  prefixIcon: Icon(Icons.auto_awesome),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'distribution',
                    child: Text('典型配网工程模板 (16 YX + 8 YC + 4 DP + 2 YM)'),
                  ),
                  DropdownMenuItem(
                    value: 'substation',
                    child: Text('标准变电站模板 (32 YX + 16 YC + 8 DP + 4 YM)'),
                  ),
                  DropdownMenuItem(
                    value: 'default',
                    child: Text('默认全功能综合站模板 (带自动曲线配置)'),
                  ),
                  DropdownMenuItem(
                    value: 'empty',
                    child: Text('空白从站 (纯净手动加点)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTemplate = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: const Text('确认新增'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final ca = int.parse(_caCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              widget.server.addStation(
                ca,
                name: name,
                template: _selectedTemplate == 'empty' ? null : _selectedTemplate,
              );
              Navigator.pop(context);
              widget.onAdded?.call(ca);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已成功创建服务端从站: $name (COA=$ca)'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
