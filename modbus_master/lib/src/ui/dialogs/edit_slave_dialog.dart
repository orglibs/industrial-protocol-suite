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
    _nameCtrl = TextEditingController(text: s?.name ?? 'Slave${DateTime.now().millisecondsSinceEpoch % 100}');
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
        const SnackBar(content: Text('Slave ID: 1-247')),
      );
      return;
    }

    if (widget.slave != null) {
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
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('slaveAlias'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices_other),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('slaveId'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scanRateCtrl,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('respDelay'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _addressType,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('addrBase'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0-based (00000 - 09999)')),
                  DropdownMenuItem(value: 1, child: Text('1-based (00001 - 10000)')),
                  DropdownMenuItem(value: 2, child: Text('PLC Modicon (0x/1x/3x/40001+)')),
                ],
                onChanged: (v) => setState(() => _addressType = v ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModbusByteOrder>(
                initialValue: _byteOrder,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('byteOrder'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.swap_horiz),
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
