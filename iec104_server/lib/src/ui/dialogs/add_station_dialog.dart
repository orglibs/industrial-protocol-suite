import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';

class AddStationDialog extends StatefulWidget {
  final Iec104Server? server;
  final Iec104ConnectionConfig? connection;
  final ValueChanged<int>? onAdded;

  const AddStationDialog({
    super.key,
    this.server,
    this.connection,
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

  Iec104Server get _effectiveServer => widget.connection?.server ?? widget.server!;

  @override
  void initState() {
    super.initState();
    int nextCa = 1;
    final stationsMap = _effectiveServer.stations;
    while (stationsMap.containsKey(nextCa)) {
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
                  if (_effectiveServer.stations.containsKey(v)) {
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
                  labelText: AppI18n.instance.t('pointTemplate'),
                  prefixIcon: const Icon(Icons.auto_awesome),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'distribution',
                    child: Text(AppI18n.instance.t('templateDistribution')),
                  ),
                  DropdownMenuItem(
                    value: 'substation',
                    child: Text(AppI18n.instance.t('templateSubstation')),
                  ),
                  DropdownMenuItem(
                    value: 'default',
                    child: Text(AppI18n.instance.t('templateDefault')),
                  ),
                  DropdownMenuItem(
                    value: 'empty',
                    child: Text(AppI18n.instance.t('templateEmpty')),
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
              final st = Station(commonAddress: ca, name: name);

              if (_selectedTemplate == 'default') {
                final def = Station.createDefault(commonAddress: ca, name: name);
                for (final p in def.pointList) {
                  st.addPoint(p);
                }
              } else if (_selectedTemplate == 'distribution') {
                final def = Station.createDistributionStation(commonAddress: ca, name: name);
                for (final p in def.pointList) {
                  st.addPoint(p);
                }
              } else if (_selectedTemplate == 'substation') {
                st.applyTemplate('substation');
              }

              if (widget.connection != null) {
                widget.connection!.addStation(st);
              } else {
                widget.server?.addStation(
                  ca,
                  name: name,
                  template: _selectedTemplate == 'empty' ? null : _selectedTemplate,
                );
              }

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
