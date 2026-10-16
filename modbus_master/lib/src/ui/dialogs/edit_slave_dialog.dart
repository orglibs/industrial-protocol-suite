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
        const SnackBar(content: Text('从站ID必须在 1 ~ 247 之间')),
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
      title: Text(isEdit ? '编辑从站设备' : '添加从站设备 (Add Slave)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '从站名称 (Slave Name)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.devices_other),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idCtrl,
                decoration: const InputDecoration(
                  labelText: '从站地址 Unit ID (1 ~ 247)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scanRateCtrl,
                decoration: const InputDecoration(
                  labelText: '巡检扫描周期 Scan Rate (ms)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _addressType,
                decoration: const InputDecoration(
                  labelText: '寄存器地址基数类型 (Address Base)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0-based (协议原生 00000 起始)')),
                  DropdownMenuItem(value: 1, child: Text('1-based (自然计数 00001 起始)')),
                  DropdownMenuItem(value: 2, child: Text('PLC标准 (40001/30001/10001)')),
                ],
                onChanged: (v) => setState(() => _addressType = v ?? 0),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ModbusByteOrder>(
                initialValue: _byteOrder,
                decoration: const InputDecoration(
                  labelText: '默认字节序 (Byte Order)',
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
                title: const Text('手动刷新模式 (禁止自动轮询)'),
                subtitle: const Text('开启后只有点击刷新按钮才会下发采集请求'),
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
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(isEdit ? '保存更改' : '添加从站'),
        ),
      ],
    );
  }
}
