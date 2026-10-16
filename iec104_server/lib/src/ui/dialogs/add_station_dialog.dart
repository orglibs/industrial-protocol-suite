import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../server/iec104_server.dart';

class AddStationDialog extends StatefulWidget {
  final Iec104Server server;
  final ValueChanged<int>? onAdded;

  const AddStationDialog({
    super.key,
    required this.server,
    this.onAdded,
  });

  @override
  State<AddStationDialog> createState() => _AddStationDialogState();
}

class _AddStationDialogState extends State<AddStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _caCtrl;
  late TextEditingController _nameCtrl;
  String _selectedTemplate = 'distribution';

  @override
  void initState() {
    super.initState();
    int nextCa = 1;
    while (widget.server.stations.containsKey(nextCa)) {
      nextCa++;
    }
    _caCtrl = TextEditingController(text: nextCa.toString());
    _nameCtrl = TextEditingController(text: 'Station #$nextCa');
  }

  @override
  void dispose() {
    _caCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppI18n.instance.t('addStation')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a logical slave station (Common Address COA) to the IEC 104 server.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _caCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('coa'),
                  helperText: '1 ~ 65535',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  final v = int.tryParse(val ?? '');
                  if (v == null || v < 1 || v > 65535) {
                    return '1 ~ 65535';
                  }
                  if (widget.server.stations.containsKey(v)) {
                    return 'COA=$v already exists';
                  }
                  return null;
                },
                onChanged: (val) {
                  final v = int.tryParse(val);
                  if (v != null && (_nameCtrl.text.isEmpty || _nameCtrl.text.startsWith('Station #'))) {
                    _nameCtrl.text = 'Station #$v';
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('stationName'),
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return AppI18n.instance.t('valRequired');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTemplate,
                decoration: InputDecoration(
                  labelText: 'Point Template',
                  prefixIcon: Icon(Icons.auto_awesome),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'distribution',
                    child: const Text('Distribution Grid (16 SP + 8 ME + 4 DP + 2 IT)'),
                  ),
                  DropdownMenuItem(
                    value: 'substation',
                    child: const Text('Substation Standard (32 SP + 16 ME + 8 DP + 4 IT)'),
                  ),
                  DropdownMenuItem(
                    value: 'default',
                    child: const Text('Full Featured Demo with Auto-Curves'),
                  ),
                  DropdownMenuItem(
                    value: 'empty',
                    child: const Text('Blank Station (Manual)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTemplate = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppI18n.instance.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: Text(AppI18n.instance.t('confirm')),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final ca = int.parse(_caCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              widget.server.addStation(
                ca,
                name: name,
                template: _selectedTemplate == 'empty' ? null : _selectedTemplate,
              );
              Navigator.pop(context);
              widget.onAdded?.call(ca);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Created station: $name (COA=$ca)'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
