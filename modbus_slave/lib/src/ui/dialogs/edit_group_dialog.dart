import 'package:flutter/material.dart';
import '../../models/register_group.dart';

class EditGroupDialog extends StatefulWidget {
  final RegisterGroupModel? initialGroup;

  const EditGroupDialog({super.key, this.initialGroup});

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _startAddressController;
  late TextEditingController _quantityController;

  ModbusRegisterType _type = ModbusRegisterType.holdingRegisters;

  @override
  void initState() {
    super.initState();
    final g = widget.initialGroup;
    _nameController = TextEditingController(text: g?.groupName ?? '新寄存器组 (Group)');
    _startAddressController = TextEditingController(text: (g?.startAddress ?? 0).toString());
    _quantityController = TextEditingController(text: (g?.quantity ?? 10).toString());

    if (g != null) {
      _type = g.registerType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startAddressController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.folder_copy_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.initialGroup == null ? '添加寄存器组' : '编辑寄存器组'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '寄存器组名称 (Group Name)',
                  hintText: '如: 遥测模拟量采样',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '组名称不能为空' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModbusRegisterType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: '寄存器类型 (Register Type)',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ModbusRegisterType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.label));
                }).toList(),
                onChanged: (v) => setState(() => _type = v ?? ModbusRegisterType.holdingRegisters),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startAddressController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '起始地址 (Start Address)',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final a = int.tryParse(v ?? '');
                        if (a == null || a < 0 || a > 65535) return '范围 0-65535';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '点数/数量 (Quantity)',
                        prefixIcon: Icon(Icons.format_list_numbered),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final q = int.tryParse(v ?? '');
                        if (q == null || q < 1) return '数量至少为1';
                        final isBit = _type == ModbusRegisterType.coils || _type == ModbusRegisterType.discreteInputs;
                        if (!isBit && q > 125) return '单次最多125字';
                        if (isBit && q > 2000) return '单次最多2000位';
                        return null;
                      },
                    ),
                  ),
                ],
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
          label: const Text('确定'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final startAddr = int.parse(_startAddressController.text.trim());
              final qty = int.parse(_quantityController.text.trim());

              final group = widget.initialGroup ??
                  RegisterGroupModel(
                    groupName: _nameController.text.trim(),
                    registerType: _type,
                    startAddress: startAddr,
                    quantity: qty,
                  );

              group.groupName = _nameController.text.trim();
              group.registerType = _type;
              group.startAddress = startAddr;
              group.quantity = qty;
              group.syncRegisters();

              Navigator.of(context).pop(group);
            }
          },
        ),
      ],
    );
  }
}
