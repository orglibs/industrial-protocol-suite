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
    _nameController = TextEditingController(text: s?.name ?? '新从站 (Slave)');
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
          Text(widget.initialSlave == null ? '新建从站设备' : '编辑从站配置'),
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
                  labelText: '从站别名 (Slave Alias)',
                  hintText: '如: 1#变压器测控从站',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '从站别名不能为空' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _slaveIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '从站地址 (Slave ID 1-247)',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final id = int.tryParse(v ?? '');
                        if (id == null || id < 1 || id > 247) return '范围 1-247';
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
                        labelText: '应答延迟 (Response Delay)',
                        suffixText: 'ms',
                        prefixIcon: Icon(Icons.timer_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final d = int.tryParse(v ?? '');
                        if (d == null || d < 0) return '不能为负数';
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
                  labelText: '寄存器地址编号模式',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('0基准偏移 (00000 - 09999)')),
                  DropdownMenuItem(value: 1, child: Text('1基准偏移 (00001 - 10000)')),
                  DropdownMenuItem(value: 2, child: Text('PLC标准格式 (0x/1x/3x/40001+)')),
                ],
                onChanged: (v) => setState(() => _addressType = v ?? 0),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ModbusByteOrder>(
                value: _byteOrder,
                decoration: const InputDecoration(
                  labelText: '大小端字节序 (Byte Order)',
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
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('确定'),
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
