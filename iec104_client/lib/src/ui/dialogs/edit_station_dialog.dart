import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';

class EditStationDialog extends StatefulWidget {
  final Iec104Client client;
  final ClientStationModel station;
  final void Function(int ca)? onStationChanged;
  final VoidCallback? onStationDeleted;

  const EditStationDialog({
    super.key,
    required this.client,
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

  void _confirmDelete() {
    final i18n = AppI18n.instance;
    if (widget.client.stations.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.t('cannotDeleteLastStation')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(i18n.t('deleteStationConfirm')),
          ],
        ),
        content: Text(
          '${i18n.t('deleteStationConfirm')}\n[${widget.station.displayName}] (COA: ${widget.station.commonAddress})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // Close confirm
              Navigator.pop(context); // Close edit dialog
              final deletedCa = widget.station.commonAddress;
              widget.client.removeStation(deletedCa);
              widget.onStationDeleted?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${i18n.t('deleteStation')}: COA = $deletedCa'),
                ),
              );
            },
            child: Text(i18n.t('confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final pointCount = widget.station.points.length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(i18n.t('editStation')),
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
                      Icon(Icons.info_outline, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${i18n.t('totalPoints')}: $pointCount. (COA: ${widget.station.commonAddress})',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
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
                    if (n != widget.station.commonAddress && widget.client.stations.containsKey(n)) {
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
              label: Text(i18n.t('deleteStation'), style: const TextStyle(color: Colors.red)),
              onPressed: _confirmDelete,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(i18n.t('cancel')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  final newCa = int.parse(_caCtrl.text.trim());
                  final newName = _nameCtrl.text.trim();
                  final oldCa = widget.station.commonAddress;

                  widget.client.updateStation(oldCa, newCa, newName);
                  Navigator.pop(context);
                  widget.onStationChanged?.call(newCa);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${i18n.t('stationName')}: $newName (COA: $newCa)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(i18n.t('save')),
            ),
          ],
        ),
      ],
    );
  }
}
