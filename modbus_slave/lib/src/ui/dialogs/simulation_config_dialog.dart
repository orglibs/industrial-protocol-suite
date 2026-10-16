import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/simulation_config.dart';

class SimulationConfigDialog extends StatefulWidget {
  final SimulationConfig initialConfig;
  final String title;

  const SimulationConfigDialog({
    super.key,
    required this.initialConfig,
    this.title,
  });

  @override
  State<SimulationConfigDialog> createState() => _SimulationConfigDialogState();
}

class _SimulationConfigDialogState extends State<SimulationConfigDialog> {
  late bool _enabled;
  late EaseWaveType _waveType;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _stepController;
  late TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _enabled = c.enabled;
    _waveType = c.waveType == EaseWaveType.none ? EaseWaveType.sine : c.waveType;
    _minController = TextEditingController(text: c.min.toString());
    _maxController = TextEditingController(text: c.max.toString());
    _stepController = TextEditingController(text: c.step.toString());
    _durationController = TextEditingController(text: c.durationMs.toString());
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _stepController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  SimulationConfig _currentConfig() {
    final minVal = double.tryParse(_minController.text.trim()) ?? 0.0;
    final maxVal = double.tryParse(_maxController.text.trim()) ?? 100.0;
    final stepVal = double.tryParse(_stepController.text.trim()) ?? 1.0;
    final dur = int.tryParse(_durationController.text.trim()) ?? 2000;
    return SimulationConfig(
      enabled: _enabled,
      waveType: _waveType,
      min: minVal,
      max: maxVal,
      step: stepVal,
      durationMs: dur,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cfg = _currentConfig();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.waves, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text(AppI18n.instance.t('enableSim')),
                subtitle: Text(AppI18n.instance.t('enableSimSub')),
                value: _enabled,
                onChanged: (val) => setState(() => _enabled = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EaseWaveType>(
                value: _waveType,
                decoration: const InputDecoration(
                  labelText: AppI18n.instance.t('waveType'),
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.show_chart),
                ),
                items: EaseWaveType.values.where((w) => w != EaseWaveType.none).map((w) {
                  return DropdownMenuItem(value: w, child: Text(w.label));
                }).toList(),
                onChanged: (v) => setState(() => _waveType = v ?? EaseWaveType.sine),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('waveMin'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('waveMax'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('wavePeriod'),
                        suffixText: 'ms',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _stepController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: AppI18n.instance.t('waveStep'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${AppI18n.instance.t('colSim')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: CustomPaint(
                  painter: _WaveformPreviewPainter(
                    config: cfg,
                    lineColor: theme.colorScheme.primary,
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
          child: Text(AppI18n.instance.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(AppI18n.instance.t('confirm')),
          onPressed: () {
            Navigator.of(context).pop(_currentConfig());
          },
        ),
      ],
    );
  }
}

class _WaveformPreviewPainter extends CustomPainter {
  final SimulationConfig config;
  final Color lineColor;

  _WaveformPreviewPainter({required this.config, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = 80;

    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final val = config.compute(t);
      final range = (config.max - config.min).abs();
      final norm = range > 1e-9 ? (val - config.min) / range : 0.5;

      final x = t * size.width;
      final y = size.height - (norm.clamp(0.0, 1.0) * (size.height - 16) + 8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPreviewPainter oldDelegate) {
    return oldDelegate.config.waveType != config.waveType ||
        oldDelegate.config.min != config.min ||
        oldDelegate.config.max != config.max;
  }
}
