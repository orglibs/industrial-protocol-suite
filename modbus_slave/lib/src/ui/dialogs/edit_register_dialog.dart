import '../../i18n/app_i18n.dart';
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
          Text('${AppI18n.instance.t('configRegTitle')} [${widget.formattedAddress}]'),
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
                          labelText: AppI18n.instance.t('colAlias'),
                          hintText: 'e.g. Phase A Voltage',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _valueController,
                        decoration: const InputDecoration(
                          labelText: AppI18n.instance.t('currValue'),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return AppI18n.instance.t('valRequired');
                          final words = ModbusDataConverter.parseInputTextToWords(
                            v.trim(),
                            _format,
                            widget.byteOrder,
                          );
                          if (words == null) return AppI18n.instance.t('convertFailed');
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
                    labelText: AppI18n.instance.t('dataFormat'),
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
                    labelText: AppI18n.instance.t('colComposite'),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text(AppI18n.instance.t('singleWord'))),
                    DropdownMenuItem(value: 1, child: Text(AppI18n.instance.t('doubleWord'))),
                    DropdownMenuItem(value: 2, child: Text(AppI18n.instance.t('quadWord'))),
                  ],
                  onChanged: (v) => setState(() => _compositeType = v ?? 0),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commentController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: AppI18n.instance.t('colComment'),
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
                          ? '${AppI18n.instance.t('simRunningStatus')}: ${r.simulation.waveType.label}'
                          : AppI18n.instance.t('enableSim'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: r.simulation.enabled ? Colors.green : null,
                      ),
                    ),
                    subtitle: Text(
                      r.simulation.enabled
                          ? 'Min: ${r.simulation.min} ~ Max: ${r.simulation.max}, ${r.simulation.durationMs}ms'
                          : AppI18n.instance.t('enableSimSub'),
                    ),
                    trailing: OutlinedButton(
                      child: Text(AppI18n.instance.t('colSim')),
                      onPressed: () async {
                        final res = await showDialog<dynamic>(
                          context: context,
                          builder: (_) => SimulationConfigDialog(
                            initialConfig: r.simulation,
                            title: '${AppI18n.instance.t('simConfigTitle')} [${widget.formattedAddress}]',
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
          child: Text(AppI18n.instance.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(AppI18n.instance.t('save')),
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
