import '../../i18n/app_i18n.dart';
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
    _nameController = TextEditingController(text: g?.displayGroupName ?? 'Group');
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
          Expanded(
            child: Text(
              widget.initialGroup == null ? AppI18n.instance.t('newGroupTitle') : AppI18n.instance.t('editGroupTitle'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('groupName'),
                  hintText: AppI18n.instance.t('groupNameHint'),
                  prefixIcon: const Icon(Icons.label_outline),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? AppI18n.instance.t('groupNameRequired') : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModbusRegisterType>(
                value: _type,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('regType'),
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: AppI18n.instance.t('startAddr'),
                        prefixIcon: const Icon(Icons.pin_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final a = int.tryParse(v ?? '');
                        if (a == null || a < 0 || a > 65535) return '0-65535';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppI18n.instance.t('regQty'),
                        prefixIcon: const Icon(Icons.format_list_numbered),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final q = int.tryParse(v ?? '');
                        if (q == null || q < 1) return '>= 1';
                        final isBit = _type == ModbusRegisterType.coils || _type == ModbusRegisterType.discreteInputs;
                        if (!isBit && q > 125) return '<= 125';
                        if (isBit && q > 2000) return '<= 2000';
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
          child: Text(AppI18n.instance.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(AppI18n.instance.t('confirm')),
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
              group.groupNameKey = null;
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
