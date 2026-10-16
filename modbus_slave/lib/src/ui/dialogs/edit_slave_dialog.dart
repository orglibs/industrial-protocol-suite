import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_data_types.dart';

class EditSlaveDialog extends StatefulWidget {
  final SlaveModel? initialSlave;

  const EditSlaveDialog({super.key, this.initialSlave});

  @override
  State<EditSlaveDialog> createState() => _EditSlaveDialogState();
}

class _EditSlaveDialogState extends State<EditSlaveDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _slaveIdController;
  late TextEditingController _delayController;

  int _addressType = 0;
  ModbusByteOrder _byteOrder = ModbusByteOrder.abcd;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSlave;
    _nameController = TextEditingController(text: s?.name ?? 'Slave');
    _slaveIdController = TextEditingController(text: (s?.slaveId ?? 1).toString());
    _delayController = TextEditingController(text: (s?.responseDelay ?? 0).toString());

    if (s != null) {
      _addressType = s.registerAddressesType;
      _byteOrder = s.byteOrder;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slaveIdController.dispose();
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.developer_board, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(widget.initialSlave == null ? AppI18n.instance.t('newSlaveTitle') : AppI18n.instance.t('editSlaveTitle')),
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
                  labelText: AppI18n.instance.t('slaveAlias'),
                  hintText: AppI18n.instance.t('slaveAliasHint'),
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? AppI18n.instance.t('slaveAliasRequired') : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _slaveIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('slaveId'),
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final id = int.tryParse(v ?? '');
                        if (id == null || id < 1 || id > 247) return '1-247';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _delayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('respDelay'),
                        suffixText: 'ms',
                        prefixIcon: Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final d = int.tryParse(v ?? '');
                        if (d == null || d < 0) return '>= 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _addressType,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('addrBase'),
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0-based (00000 - 09999)')),
                  DropdownMenuItem(value: 1, child: Text('1-based (00001 - 10000)')),
                  DropdownMenuItem(value: 2, child: Text('PLC Modicon (0x/1x/3x/40001+)')),
                ],
                onChanged: (v) => setState(() => _addressType = v ?? 0),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModbusByteOrder>(
                value: _byteOrder,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('byteOrder'),
                  prefixIcon: Icon(Icons.swap_vertical_circle_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ModbusByteOrder.values.map((o) {
                  return DropdownMenuItem(value: o, child: Text(o.label));
                }).toList(),
                onChanged: (v) => setState(() => _byteOrder = v ?? ModbusByteOrder.abcd),
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
              final slaveId = int.parse(_slaveIdController.text.trim());
              final delay = int.parse(_delayController.text.trim());
              final slave = widget.initialSlave ??
                  SlaveModel(
                    name: _nameController.text.trim(),
                    slaveId: slaveId,
                    registerAddressesType: _addressType,
                    responseDelay: delay,
                    byteOrder: _byteOrder,
                  );

              slave.name = _nameController.text.trim();
              slave.slaveId = slaveId;
              slave.registerAddressesType = _addressType;
              slave.responseDelay = delay;
              slave.byteOrder = _byteOrder;

              Navigator.of(context).pop(slave);
            }
          },
        ),
      ],
    );
  }
}
