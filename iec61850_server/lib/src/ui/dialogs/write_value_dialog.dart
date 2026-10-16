import 'package:flutter/material.dart';
import '../../models/scl_models.dart';
import '../../models/server_variable_model.dart';

class WriteValueDialog extends StatefulWidget {
  final ServerVariableModel variable;
  final void Function(ServerVariableModel variable, dynamic newValue, int quality) onSaved;

  const WriteValueDialog({
    super.key,
    required this.variable,
    required this.onSaved,
  });

  @override
  State<WriteValueDialog> createState() => _WriteValueDialogState();
}

class _WriteValueDialogState extends State<WriteValueDialog> {
  late TextEditingController _valCtrl;
  late bool _boolVal;
  late int _quality;

  @override
  void initState() {
    super.initState();
    _quality = widget.variable.quality;
    if (widget.variable.type == IecBasicType.boolean) {
      _boolVal = widget.variable.value == true;
      _valCtrl = TextEditingController(text: _boolVal.toString());
    } else {
      _boolVal = false;
      _valCtrl = TextEditingController(text: widget.variable.value?.toString() ?? '');
    }
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  void _save() {
    dynamic finalVal;
    if (widget.variable.type == IecBasicType.boolean) {
      finalVal = _boolVal;
    } else if (widget.variable.type == IecBasicType.float32 || widget.variable.type == IecBasicType.float64) {
      finalVal = double.tryParse(_valCtrl.text) ?? widget.variable.value;
    } else if (widget.variable.type.name.startsWith('int') || widget.variable.type.name.startsWith('uint')) {
      finalVal = int.tryParse(_valCtrl.text) ?? widget.variable.value;
    } else {
      finalVal = _valCtrl.text;
    }

    widget.onSaved(widget.variable, finalVal, _quality);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('写入变量值 / 控制操作'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.variable.shortRef,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Full Ref: ${widget.variable.reference}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text('FC: ${widget.variable.fcCode}', style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('Type: ${widget.variable.type.name}', style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('目标数据值 (Value):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (widget.variable.type == IecBasicType.boolean)
                SwitchListTile(
                  title: Text(_boolVal ? 'TRUE (合闸 / 动作 / 1)' : 'FALSE (分闸 / 复位 / 0)'),
                  value: _boolVal,
                  onChanged: (val) {
                    setState(() {
                      _boolVal = val;
                      _valCtrl.text = val.toString();
                    });
                  },
                )
              else
                TextField(
                  controller: _valCtrl,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: '输入数值，如 220.5 或 1',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _valCtrl.clear(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('品质状态 (Quality Flags):', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text('有效 (Good)'),
                    selected: _quality == 0,
                    onSelected: (sel) {
                      setState(() {
                        if (sel) _quality = 0;
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('无效 (Invalid)'),
                    selected: (_quality & 0x01) != 0,
                    onSelected: (sel) {
                      setState(() {
                        _quality = sel ? (_quality | 0x01) : (_quality & ~0x01);
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('超范围 (OutOfRange)'),
                    selected: (_quality & 0x04) != 0,
                    onSelected: (sel) {
                      setState(() {
                        _quality = sel ? (_quality | 0x04) : (_quality & ~0x04);
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('测试模式 (Test)'),
                    selected: (_quality & 0x2000) != 0,
                    onSelected: (sel) {
                      setState(() {
                        _quality = sel ? (_quality | 0x2000) : (_quality & ~0x2000);
                      });
                    },
                  ),
                  FilterChip(
                    label: const Text('闭锁 (Blocked)'),
                    selected: (_quality & 0x4000) != 0,
                    onSelected: (sel) {
                      setState(() {
                        _quality = sel ? (_quality | 0x4000) : (_quality & ~0x4000);
                      });
                    },
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
          label: const Text('写入并生效'),
          onPressed: _save,
        ),
      ],
    );
  }
}
