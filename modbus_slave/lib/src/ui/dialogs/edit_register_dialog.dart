import 'package:flutter/material.dart';
import '../../models/register_model.dart';
import '../../protocol/modbus_data_types.dart';
import 'simulation_config_dialog.dart';

class EditRegisterDialog extends StatefulWidget {
  final RegisterModel register;
  final String formattedAddress;
  final ModbusByteOrder byteOrder;
  final List<int>? neighborWords;

  const EditRegisterDialog({
    super.key,
    required this.register,
    required this.formattedAddress,
    required this.byteOrder,
    this.neighborWords,
  });

  @override
  State<EditRegisterDialog> createState() => _EditRegisterDialogState();
}

class _EditRegisterDialogState extends State<EditRegisterDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aliasController;
  late TextEditingController _valueController;
  late TextEditingController _commentController;

  late RegisterDataFormat _format;
  late int _compositeType;

  @override
  void initState() {
    super.initState();
    final r = widget.register;
    _aliasController = TextEditingController(text: r.alias ?? '');
    _valueController = TextEditingController(
      text: r.getDisplayValue(widget.byteOrder, widget.neighborWords),
    );
    _commentController = TextEditingController(text: r.comment ?? '');
    _format = r.valueFormat;
    _compositeType = r.compositeType;
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _valueController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.register;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('配置寄存器 [${widget.formattedAddress}]'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _aliasController,
                        decoration: const InputDecoration(
                          labelText: '别名 / 描述 (Alias)',
                          hintText: '如: A相电压',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        decoration: const InputDecoration(
                          labelText: '设定当前数值 (Value)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return '数值不能为空';
                          final words = ModbusDataConverter.parseInputTextToWords(
                            v.trim(),
                            _format,
                            widget.byteOrder,
                          );
                          if (words == null) return '数值格式不符合选定类型';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<RegisterDataFormat>(
                  value: _format,
                  decoration: const InputDecoration(
                    labelText: '数据显示格式 (Data Format)',
                    border: OutlineInputBorder(),
                  ),
                  items: RegisterDataFormat.values.map((f) {
                    return DropdownMenuItem(value: f, child: Text(f.label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _format = v;
                        _valueController.text = r.getDisplayValue(widget.byteOrder, widget.neighborWords);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _compositeType,
                  decoration: const InputDecoration(
                    labelText: '组合模式 (Composite Multi-Word Type)',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('单寄存器 (16位 Word)')),
                    DropdownMenuItem(value: 1, child: Text('双寄存器组合 (32位 Float / Int32)')),
                    DropdownMenuItem(value: 2, child: Text('四寄存器组合 (64位 Double / Int64)')),
                  ],
                  onChanged: (v) => setState(() => _compositeType = v ?? 0),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注说明 (Comment)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.waves,
                      color: r.simulation.enabled ? Colors.green : Colors.grey,
                    ),
                    title: Text(
                      r.simulation.enabled
                          ? '波形模拟已启用: ${r.simulation.waveType.label}'
                          : '波形模拟未启用',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.simulation.enabled ? Colors.green : null,
                      ),
                    ),
                    subtitle: Text(
                      r.simulation.enabled
                          ? '范围: ${r.simulation.min} ~ ${r.simulation.max}, 周期: ${r.simulation.durationMs}ms'
                          : '点击右侧按钮配置正弦/三角/方波/随机动态数据',
                    ),
                    trailing: OutlinedButton(
                      child: const Text('波形参数'),
                      onPressed: () async {
                        final res = await showDialog<dynamic>(
                          context: context,
                          builder: (_) => SimulationConfigDialog(
                            initialConfig: r.simulation,
                            title: '配置 [${widget.formattedAddress}] 波形模拟',
                          ),
                        );
                        if (res != null) {
                          setState(() {
                            r.simulation = res;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
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
          label: const Text('保存修改'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              r.alias = _aliasController.text.trim().isEmpty ? null : _aliasController.text.trim();
              r.comment = _commentController.text.trim().isEmpty ? null : _commentController.text.trim();
              r.valueFormat = _format;
              r.compositeType = _compositeType;
              r.parseAndSetDisplayValue(_valueController.text.trim(), widget.byteOrder);

              Navigator.of(context).pop(true);
            }
          },
        ),
      ],
    );
  }
}
