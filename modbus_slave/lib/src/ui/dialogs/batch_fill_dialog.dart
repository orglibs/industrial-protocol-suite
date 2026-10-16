import 'package:flutter/material.dart';
import '../../models/register_group.dart';

enum BatchFillMode {
  zero('全部清零 (All 0)'),
  ones('全部置 1 (All 1 / Max)'),
  constant('指定常数 (Constant)'),
  increment('线性递增 (Linear Increment)'),
  random('随机数值 (Random Range)');

  final String label;
  const BatchFillMode(this.label);
}

class BatchFillDialog extends StatefulWidget {
  final RegisterGroupModel group;

  const BatchFillDialog({super.key, required this.group});

  @override
  State<BatchFillDialog> createState() => _BatchFillDialogState();
}

class _BatchFillDialogState extends State<BatchFillDialog> {
  BatchFillMode _mode = BatchFillMode.zero;
  final TextEditingController _constController = TextEditingController(text: '100');
  final TextEditingController _startController = TextEditingController(text: '1');
  final TextEditingController _stepController = TextEditingController(text: '1');
  final TextEditingController _minController = TextEditingController(text: '10');
  final TextEditingController _maxController = TextEditingController(text: '100');

  @override
  void dispose() {
    _constController.dispose();
    _startController.dispose();
    _stepController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBit = widget.group.isBitType;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('批量填充寄存器数值 (${widget.group.groupName})'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '目标: ${widget.group.quantity} 个寄存器 (地址范围 ${widget.group.startAddress} ~ ${widget.group.startAddress + widget.group.quantity - 1})',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BatchFillMode>(
                value: _mode,
                decoration: const InputDecoration(
                  labelText: '填充模式',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.tune),
                ),
                items: BatchFillMode.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.label));
                }).toList(),
                onChanged: (v) => setState(() => _mode = v ?? BatchFillMode.zero),
              ),
              const SizedBox(height: 16),

              if (_mode == BatchFillMode.constant) ...[
                TextField(
                  controller: _constController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isBit ? '常数值 (0 或 1)' : '常数值 (0-65535)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else if (_mode == BatchFillMode.increment) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '起始值 (Start)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _stepController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '步长 (Step)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_mode == BatchFillMode.random) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '最小值 (Min)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '最大值 (Max)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
          icon: const Icon(Icons.flash_on),
          label: const Text('执行填充'),
          onPressed: () {
            switch (_mode) {
              case BatchFillMode.zero:
                widget.group.resetAll();
                break;
              case BatchFillMode.ones:
                widget.group.batchFillConstant(isBit ? 1 : 0xFFFF);
                break;
              case BatchFillMode.constant:
                final v = int.tryParse(_constController.text.trim()) ?? 0;
                widget.group.batchFillConstant(v);
                break;
              case BatchFillMode.increment:
                final start = int.tryParse(_startController.text.trim()) ?? 0;
                final step = int.tryParse(_stepController.text.trim()) ?? 1;
                widget.group.batchFillIncrement(start, step);
                break;
              case BatchFillMode.random:
                final minVal = int.tryParse(_minController.text.trim()) ?? 0;
                final maxVal = int.tryParse(_maxController.text.trim()) ?? 100;
                widget.group.batchFillRandom(minVal, maxVal);
                break;
            }
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}
