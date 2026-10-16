import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
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
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.waves, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(i18n.t('simConfigTitle')),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i18n.t("simTargetVar")}${widget.variable.shortRef}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i18n.t('enableSimulation')),
                subtitle: Text(i18n.t('enableSimSubtitle')),
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
                decoration: InputDecoration(
                  labelText: i18n.t('waveFunction'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.graphic_eq),
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
                      decoration: InputDecoration(
                        labelText: i18n.t('minVal'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: i18n.t('maxVal'),
                        border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        labelText: i18n.t('stepVal'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _durationCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: i18n.t('periodMs'),
                        border: const OutlineInputBorder(),
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
          child: Text(i18n.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(i18n.t('applyConfig')),
          onPressed: _save,
        ),
      ],
    );
  }
}
