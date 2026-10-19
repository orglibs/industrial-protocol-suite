import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../protocol/asdu.dart';

class EditPointDialog extends StatefulWidget {
  final ClientStationModel station;
  final ClientPointModel point;
  final VoidCallback? onUpdated;
  final VoidCallback? onDeleted;

  const EditPointDialog({
    super.key,
    required this.station,
    required this.point,
    this.onUpdated,
    this.onDeleted,
  });

  @override
  State<EditPointDialog> createState() => _EditPointDialogState();
}

class _EditPointDialogState extends State<EditPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.point.name);
    _valCtrl = TextEditingController(text: widget.point.value.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  dynamic _parseValue() {
    final text = _valCtrl.text.trim();
    final typeId = widget.point.typeId;
    if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) {
      return text == '1' || text.toLowerCase() == 'true';
    } else if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
      return int.tryParse(text) ?? widget.point.value;
    } else if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) {
      return double.tryParse(text) ?? widget.point.value;
    } else {
      return int.tryParse(text) ?? widget.point.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.point;
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('${i18n.t('editPoint')} (IOA: ${p.ioa})'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i18n.t('filterStation')}: CA = ${widget.station.commonAddress} (${widget.station.displayName})'),
                const SizedBox(height: 4),
                Text('${i18n.t('ioa')}: ${p.ioa} (0x${p.ioa.toRadixString(16).toUpperCase()})'),
                const SizedBox(height: 4),
                Text('${i18n.t('filterType')}: ${p.typeCategory} (Type ${p.typeId.id})'),
                const Divider(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('name'),
                    prefixIcon: const Icon(Icons.label),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return i18n.t('valRequired');
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('val'),
                    prefixIcon: const Icon(Icons.edit_note),
                    border: const OutlineInputBorder(),
                  ),
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
              label: Text(i18n.t('deletePoint'), style: const TextStyle(color: Colors.red)),
              onPressed: () {
                widget.station.removePoint(p.ioa);
                Navigator.pop(context);
                widget.onDeleted?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${i18n.t('deletePoint')}: IOA = ${p.ioa}')),
                );
              },
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
                  p.nameKey = null;
                  p.name = _nameCtrl.text.trim();
                  p.update(_parseValue(), p.quality);
                  widget.station.onDataChanged?.call();
                  Navigator.pop(context);
                  widget.onUpdated?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${i18n.t('save')}: IOA = ${p.ioa}')),
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
