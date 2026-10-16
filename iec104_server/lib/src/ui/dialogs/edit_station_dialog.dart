import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';

class EditStationDialog extends StatefulWidget {
  final Iec104Server server;
  final Station station;
  final ValueChanged<int>? onStationChanged;
  final VoidCallback? onStationDeleted;

  const EditStationDialog({
    super.key,
    required this.server,
    required this.station,
    this.onStationChanged,
    this.onStationDeleted,
  });

  @override
  State<EditStationDialog> createState() => _EditStationDialogState();
}

class _EditStationDialogState extends State<EditStationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _caCtrl;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _caCtrl = TextEditingController(text: widget.station.commonAddress.toString());
    _nameCtrl = TextEditingController(text: widget.station.name);
  }

  @override
  void dispose() {
    _caCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _confirmDeleteStation() {
    if (widget.server.stations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one station required'), backgroundColor: Colors.orange),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.instance.t('deleteStation')),
        content: Text('Delete station [COA=${widget.station.commonAddress}] "${widget.station.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppI18n.instance.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final deletedCa = widget.station.commonAddress;
              widget.server.removeStation(deletedCa);
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onStationDeleted?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted station [COA=$deletedCa]'), backgroundColor: Colors.red),
              );
            },
            child: Text(AppI18n.instance.t('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pointCount = widget.station.points.length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppI18n.instance.t('editStation')),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Points in station: $pointCount.',
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
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
                    if (v != widget.station.commonAddress && widget.server.stations.containsKey(v)) {
                      return 'COA=$v already used';
                    }
                    return null;
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
                const Text('Templates:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.electric_bolt, size: 16),
                      label: const Text('Distribution Template'),
                      onPressed: () {
                        widget.station.applyTemplate('distribution');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Imported distribution template')),
                        );
                        setState(() {});
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.account_balance, size: 16),
                      label: const Text('Substation Template'),
                      onPressed: () {
                        widget.station.applyTemplate('substation');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Imported substation template')),
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: Text(AppI18n.instance.t('deleteStation'), style: const TextStyle(color: Colors.red)),
              onPressed: widget.server.stations.length > 1 ? _confirmDeleteStation : null,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppI18n.instance.t('cancel')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  final oldCa = widget.station.commonAddress;
                  final newCa = int.parse(_caCtrl.text.trim());
                  final newName = _nameCtrl.text.trim();

                  widget.server.updateStation(oldCa, newCa, newName);
                  Navigator.pop(context);
                  widget.onStationChanged?.call(newCa);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated station: $newName (COA=$newCa)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(AppI18n.instance.t('save')),
            ),
          ],
        ),
      ],
    );
  }
}
