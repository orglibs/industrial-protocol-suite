import 'package:flutter/material.dart';
import '../../models/register_group.dart';

class EditGroupDialog extends StatefulWidget {
  final RegisterGroupModel? group;

  const EditGroupDialog({super.key, this.group});

  static Future<RegisterGroupModel?> show(BuildContext context, {RegisterGroupModel? group}) {
    return showDialog<RegisterGroupModel>(
      context: context,
      builder: (_) => EditGroupDialog(group: group),
    );
  }

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _startAddrCtrl;
  late TextEditingController _qtyCtrl;
  late ModbusRegisterType _type;
  late bool _isEnabled;

  @override
  void initState() {
    super.initState();
    final g = widget.group;
    _nameCtrl = TextEditingController(text: g?.groupName ?? '寄存器组 ${DateTime.now().millisecondsSinceEpoch % 100}');
    _startAddrCtrl = TextEditingController(text: (g?.startAddress ?? 0).toString());
    _qtyCtrl = TextEditingController(text: (g?.quantity ?? 10).toString());
    _type = g?.registerType ?? ModbusRegisterType.holdingRegisters;
    _isEnabled = g?.isPollingEnabled ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startAddrCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final startAddr = int.tryParse(_startAddrCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 10;

    if (startAddr < 0 || startAddr > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('起始地址必须在 0 ~ 65535 之间')),
      );
      return;
    }

    if (qty < 1 || qty > 125) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('寄存器数量必须在 1 ~ 125 之间 (Modbus协议限制)')),
      );
      return;
    }

    if (widget.group != null) {
      widget.group!.groupName = name;
      widget.group!.registerType = _type;
      widget.group!.startAddress = startAddr;
      widget.group!.quantity = qty;
      widget.group!.isPollingEnabled = _isEnabled;
      widget.group!.syncRegisters();
      Navigator.of(context).pop(widget.group);
    } else {
      final newGroup = RegisterGroupModel(
        groupName: name,
        registerType: _type,
        startAddress: startAddr,
        quantity: qty,
        isPollingEnabled: _isEnabled,
      );
      Navigator.of(context).pop(newGroup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.group != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑寄存器组任务' : '添加寄存器组任务 (Add Register Group)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '任务组名称 (Group Name)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_special),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModbusRegisterType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: '寄存器类型 / 功能码 (Register Type)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: ModbusRegisterType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.label));
                }).toList(),
                onChanged: (v) => setState(() => _type = v ?? ModbusRegisterType.holdingRegisters),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _startAddrCtrl,
                decoration: const InputDecoration(
                  labelText: '起始寄存器地址 Start Address (0..65535)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(
                  labelText: '读取点数 Quantity (1..125)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('启用此任务采集'),
                subtitle: const Text('控制轮询服务是否循环下发本组采集请求'),
                value: _isEnabled,
                onChanged: (v) => setState(() => _isEnabled = v),
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
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? '保存更改' : '添加组'),
        ),
      ],
    );
  }
}
