import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../i18n/app_i18n.dart';

class AddStationDialog extends StatefulWidget {
  final Iec104Client client;
  final void Function(int newCa)? onAdded;

  const AddStationDialog({
    super.key,
    required this.client,
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
    // Default COA to next available int
    int nextCa = 1;
    while (widget.client.stations.containsKey(nextCa)) {
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
    final i18n = AppI18n.instance;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(i18n.t('newStation')),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i18n.t('serverNetworkConfig'),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('coa'),
                    helperText: i18n.t('coaRange'),
                    prefixIcon: const Icon(Icons.tag),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 65535) {
                      return i18n.t('coaRange');
                    }
                    if (widget.client.stations.containsKey(n)) {
                      return i18n.t('coaExists');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('stationNamePrompt'),
                    prefixIcon: const Icon(Icons.edit_note),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return i18n.t('stationNameEmpty');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTemplate,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: i18n.t('initTemplate'),
                    prefixIcon: const Icon(Icons.auto_awesome),
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'distribution',
                      child: Text(i18n.t('tmplDistribution')),
                    ),
                    DropdownMenuItem(
                      value: 'substation',
                      child: Text(i18n.t('tmplSubstation')),
                    ),
                    DropdownMenuItem(
                      value: 'empty',
                      child: Text(i18n.t('tmplBlank')),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 18),
          label: Text(i18n.t('confirm')),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final ca = int.parse(_caCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              widget.client.addStation(
                ca,
                name: name,
                template: _selectedTemplate == 'empty' ? null : _selectedTemplate,
              );
              Navigator.pop(context);
              widget.onAdded?.call(ca);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${i18n.t('stationName')}: $name (COA: $ca)'),
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
