import 'package:flutter/material.dart';
import '../../models/server_variable_model.dart';
import '../../models/simulation_config.dart';

class SimulationDialog extends StatefulWidget {
  final ServerVariableModel variable;
  final void Function(ServerVariableModel variable) onSaved;

  const SimulationDialog({
    super.key,
    required this.variable,
    required this.onSaved,
  });

  @override
  State<SimulationDialog> createState() => _SimulationDialogState();
}

class _SimulationDialogState extends State<SimulationDialog> {
  late bool _enabled;
  late EaseWaveType _waveType;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;
  late TextEditingController _stepCtrl;
  late TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    final sim = widget.variable.simulation;
    _enabled = sim.enabled;
    _waveType = sim.waveType;
    _minCtrl = TextEditingController(text: sim.min.toString());
    _maxCtrl = TextEditingController(text: sim.max.toString());
    _stepCtrl = TextEditingController(text: sim.step.toString());
    _durationCtrl = TextEditingController(text: sim.durationMs.toString());
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _stepCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final sim = widget.variable.simulation;
    sim.enabled = _enabled;
    sim.waveType = _waveType;
    sim.min = double.tryParse(_minCtrl.text.trim()) ?? 0.0;
    sim.max = double.tryParse(_maxCtrl.text.trim()) ?? 100.0;
    sim.step = double.tryParse(_stepCtrl.text.trim()) ?? 1.0;
    sim.durationMs = int.tryParse(_durationCtrl.text.trim()) ?? 2000;

    widget.onSaved(widget.variable);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.waves, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Text('模拟量波形与动态仿真配置'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '变量：${widget.variable.shortRef}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用仿真模拟 (Enable Simulation)'),
                subtitle: const Text('周期性计算变化并触发上送报告与数据更新'),
                value: _enabled,
                onChanged: (val) {
                  setState(() {
                    _enabled = val;
                  });
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              DropdownButtonFormField<EaseWaveType>(
                value: _waveType,
                decoration: const InputDecoration(
                  labelText: '波形函数 (Waveform / EaseFunction)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.graphic_eq),
                ),
                items: EaseWaveType.values.map((w) {
                  return DropdownMenuItem(
                    value: w,
                    child: Text(w.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _waveType = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minCtrl,
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
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '最大值 (Max)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '步长 (Step)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '周期 (Period ms)',
                        border: OutlineInputBorder(),
                      ),
                    ),
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
          label: const Text('应用配置'),
          onPressed: _save,
        ),
      ],
    );
  }
}
