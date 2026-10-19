import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../server/station.dart';

class AddPointDialog extends StatefulWidget {
  final Station station;
  final void Function(StationPoint point) onAdd;

  const AddPointDialog({
    super.key,
    required this.station,
    required this.onAdd,
  });

  @override
  State<AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<AddPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ioaController;
  late TextEditingController _nameController;
  late TextEditingController _valController;

  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void initState() {
    super.initState();
    // Default IOA to max IOA + 1
    int nextIoa = 1;
    if (widget.station.pointList.isNotEmpty) {
      nextIoa = widget.station.pointList.map((p) => p.ioa).reduce((a, b) => a > b ? a : b) + 1;
    }
    _ioaController = TextEditingController(text: nextIoa.toString());
    _nameController = TextEditingController(text: 'Point #$nextIoa');
    _valController = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    _ioaController.dispose();
    _nameController.dispose();
    _valController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppI18n.instance.t('addPoint')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ioaController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('ioa'),
                  helperText: '1 ~ 16777215',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Valid positive integer';
                  if (widget.station.getPoint(n) != null) return 'IOA already exists';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AsduTypeId>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('pointType'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  AsduTypeId.mSpNa1,
                  AsduTypeId.mSpTb1,
                  AsduTypeId.mDpNa1,
                  AsduTypeId.mDpTb1,
                  AsduTypeId.mStNa1,
                  AsduTypeId.mBoNa1,
                  AsduTypeId.mMeNa1,
                  AsduTypeId.mMeNb1,
                  AsduTypeId.mMeNc1,
                  AsduTypeId.mMeTf1,
                  AsduTypeId.mItNa1,
                ].map((t) => DropdownMenuItem(
                  value: t,
                  child: Text('Type ${t.id}: ${t.nameString} (${t.description})'),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      if (v == AsduTypeId.mSpNa1 || v == AsduTypeId.mSpTb1) {
                        _nameController.text = 'SP #${_ioaController.text}';
                        _valController.text = 'false';
                      } else if (v == AsduTypeId.mDpNa1 || v == AsduTypeId.mDpTb1) {
                        _nameController.text = 'DP #${_ioaController.text}';
                        _valController.text = '1';
                      } else if (v == AsduTypeId.mItNa1) {
                        _nameController.text = 'IT #${_ioaController.text}';
                        _valController.text = '0';
                      } else {
                        _nameController.text = 'ME #${_ioaController.text}';
                        _valController.text = '0.0';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('pointName'),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? AppI18n.instance.t('valRequired') : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('currValue'),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? AppI18n.instance.t('valRequired') : null,
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
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final ioa = int.parse(_ioaController.text.trim());
              final name = _nameController.text.trim();
              final rawVal = _valController.text.trim();

              dynamic val;
              if (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1) {
                val = rawVal == 'true' || rawVal == '1';
              } else if (_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1) {
                val = int.tryParse(rawVal) ?? 1;
              } else if (_selectedType == AsduTypeId.mMeNb1 ||
                  _selectedType == AsduTypeId.mStNa1 ||
                  _selectedType == AsduTypeId.mBoNa1 ||
                  _selectedType == AsduTypeId.mItNa1) {
                val = int.tryParse(rawVal) ?? 0;
              } else {
                val = double.tryParse(rawVal) ?? 0.0;
              }

              widget.onAdd(StationPoint(
                ioa: ioa,
                typeId: _selectedType,
                name: name,
                value: val,
              ));
              Navigator.pop(context);
            }
          },
          child: Text(AppI18n.instance.t('add')),
        ),
      ],
    );
  }
}
