import 'package:flutter/material.dart';
import '../../models/client_variable_model.dart';
import '../../models/scl_models.dart';

class WriteVariableDialog extends StatefulWidget {
  final ClientVariableModel variable;
  final void Function(dynamic value) onConfirm;

  const WriteVariableDialog({
    super.key,
    required this.variable,
    required this.onConfirm,
  });

  @override
  State<WriteVariableDialog> createState() => _WriteVariableDialogState();
}

class _WriteVariableDialogState extends State<WriteVariableDialog> {
  late TextEditingController _valCtrl;
  late bool _boolVal;

  @override
  void initState() {
    super.initState();
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

  void _submit() {
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

    widget.onConfirm(finalVal);
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
          const Text('写入数据属性 (MMS Write)'),
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
                        const Spacer(),
                        Text('当前值: ${widget.variable.displayValue}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('写入目标数值 (Target Value):', style: TextStyle(fontWeight: FontWeight.w600)),
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
          icon: const Icon(Icons.send),
          label: const Text('发送写入请求'),
          onPressed: _submit,
        ),
      ],
    );
  }
}
