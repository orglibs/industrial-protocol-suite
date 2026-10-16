import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';

class AddStationDialog extends StatefulWidget {
  final Iec104Client client;
  final void Function(int newCa)? onAdded;

  const AddStationDialog({
    super.key,
    required this.client,
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
    // Default COA to next available int
    int nextCa = 1;
    while (widget.client.stations.containsKey(nextCa)) {
      nextCa++;
    }
    _caCtrl = TextEditingController(text: nextCa.toString());
    _nameCtrl = TextEditingController(text: '从站 #$nextCa (变电站)');
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
          Text('新建从站 (Add Station / Slave)'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '配置新的 IEC 104 从站公共地址 (COA) 与点位初始化模板：',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caCtrl,
                  decoration: const InputDecoration(
                    labelText: '从站公共地址 (COA / CA)',
                    helperText: '范围: 1 ~ 65535 (十进制)',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 65535) {
                      return '请输入 1 ~ 65535 之间的有效整数';
                    }
                    if (widget.client.stations.containsKey(n)) {
                      return '该 COA 地址 ($n) 已存在，请更换';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '从站名称 (Station Name)',
                    helperText: '例如: 110kV 西郊站 / 2号变电所',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '从站名称不能为空';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplate,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '点位初始化模板',
                    prefixIcon: Icon(Icons.auto_awesome),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'distribution',
                      child: Text('典型配网模板 (16遥信+8遥测+4双点遥信+2累计量)'),
                    ),
                    DropdownMenuItem(
                      value: 'substation',
                      child: Text('典型变电站模板 (32遥信+16遥测+8双点遥信+4电能量)'),
                    ),
                    DropdownMenuItem(
                      value: 'empty',
                      child: Text('空白从站 (不预置点位，后续手动/批量添加)'),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: const Text('创建从站'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final ca = int.parse(_caCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              widget.client.addStation(
                ca,
                name: name,
                template: _selectedTemplate == 'empty' ? null : _selectedTemplate,
              );
              Navigator.pop(context);
              widget.onAdded?.call(ca);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已成功创建从站: $name (COA: $ca)'),
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
