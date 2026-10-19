import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_data_types.dart';

class EditSlaveDialog extends StatefulWidget {
  final SlaveModel? slave;

  const EditSlaveDialog({super.key, this.slave});

  static Future<SlaveModel?> show(BuildContext context, {SlaveModel? slave}) {
    return showDialog<SlaveModel>(
      context: context,
      builder: (_) => EditSlaveDialog(slave: slave),
    );
  }

  @override
  State<EditSlaveDialog> createState() => _EditSlaveDialogState();
}

class _EditSlaveDialogState extends State<EditSlaveDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _idCtrl;
  late TextEditingController _scanRateCtrl;
  late int _addressType;
  late bool _isManual;
  late ModbusByteOrder _byteOrder;

  @override
  void initState() {
    super.initState();
    final s = widget.slave;
    _nameCtrl = TextEditingController(text: s?.displayName ?? 'Slave${DateTime.now().millisecondsSinceEpoch % 100}');
    _idCtrl = TextEditingController(text: (s?.slaveId ?? 1).toString());
    _scanRateCtrl = TextEditingController(text: (s?.scanRate ?? 1000).toString());
    _addressType = s?.registerAddressesType ?? 0;
    _isManual = s?.isManualRefresh ?? false;
    _byteOrder = s?.byteOrder ?? ModbusByteOrder.abcd;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _scanRateCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final id = int.tryParse(_idCtrl.text.trim()) ?? 1;
    final rate = int.tryParse(_scanRateCtrl.text.trim()) ?? 1000;

    if (id < 1 || id > 247) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppI18n.instance.t('slaveId')}: 1-247')),
      );
      return;
    }

    if (widget.slave != null) {
      if (widget.slave!.nameKey != null && name != AppI18n.instance.t(widget.slave!.nameKey!)) {
        widget.slave!.nameKey = null;
      }
      widget.slave!.name = name;
      widget.slave!.slaveId = id;
      widget.slave!.scanRate = rate;
      widget.slave!.registerAddressesType = _addressType;
      widget.slave!.isManualRefresh = _isManual;
      widget.slave!.byteOrder = _byteOrder;
      Navigator.of(context).pop(widget.slave);
    } else {
      final newSlave = SlaveModel(
        name: name,
        slaveId: id,
        scanRate: rate,
        registerAddressesType: _addressType,
        isManualRefresh: _isManual,
        byteOrder: _byteOrder,
      );
      Navigator.of(context).pop(newSlave);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.slave != null;
    return AlertDialog(
      title: Text(isEdit ? AppI18n.instance.t('editSlaveTitle') : AppI18n.instance.t('newSlaveTitle')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('slaveAlias'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.devices_other),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('slaveId'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scanRateCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('refreshRate'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _addressType,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('addrBase'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(AppI18n.instance.t('addrMode0'))),
                  DropdownMenuItem(value: 1, child: Text(AppI18n.instance.t('addrMode1'))),
                  DropdownMenuItem(value: 2, child: Text(AppI18n.instance.t('addrModeModicon'))),
                ],
                onChanged: (v) => setState(() => _addressType = v ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModbusByteOrder>(
                initialValue: _byteOrder,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('byteOrder'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.swap_horiz),
                ),
                items: ModbusByteOrder.values.map((order) {
                  return DropdownMenuItem(value: order, child: Text(order.label));
                }).toList(),
                onChanged: (v) => setState(() => _byteOrder = v ?? ModbusByteOrder.abcd),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(AppI18n.instance.t('pollPaused')),
                subtitle: Text(AppI18n.instance.t('pollTooltipPaused')),
                value: _isManual,
                onChanged: (v) => setState(() => _isManual = v),
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
