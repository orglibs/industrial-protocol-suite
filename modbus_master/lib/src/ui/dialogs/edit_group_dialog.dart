import '../../i18n/app_i18n.dart';
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
    _nameCtrl = TextEditingController(text: g?.displayGroupName ?? 'Group ${DateTime.now().millisecondsSinceEpoch % 100}');
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
        SnackBar(content: Text('${AppI18n.instance.t('startAddr')}: 0-65535')),
      );
      return;
    }

    if (qty < 1 || qty > 125) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppI18n.instance.t('regQty')}: 1-125')),
      );
      return;
    }

    if (widget.group != null) {
      if (widget.group!.groupNameKey != null && name != AppI18n.instance.t(widget.group!.groupNameKey!)) {
        widget.group!.groupNameKey = null;
      }
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
      title: Text(isEdit ? AppI18n.instance.t('editGroupTitle') : AppI18n.instance.t('newGroupTitle')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('groupName'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.folder_special),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModbusRegisterType>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('regType'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: ModbusRegisterType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.label));
                }).toList(),
                onChanged: (v) => setState(() => _type = v ?? ModbusRegisterType.holdingRegisters),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _startAddrCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('startAddr'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('regQty'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(AppI18n.instance.t('enableSim')),
                subtitle: Text(AppI18n.instance.t('enableSimSub')),
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
          child: Text(AppI18n.instance.t('cancel')),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? AppI18n.instance.t('save') : AppI18n.instance.t('confirm')),
        ),
      ],
    );
  }
}
