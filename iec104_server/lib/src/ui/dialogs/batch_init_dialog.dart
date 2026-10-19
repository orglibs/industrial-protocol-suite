import "../../i18n/app_i18n.dart";
import 'package:flutter/material.dart';
import '../../protocol/asdu.dart';
import '../../server/station.dart';

class BatchInitDialog extends StatefulWidget {
  final Station station;
  final void Function({
    required AsduTypeId typeId,
    required int startIoa,
    required int count,
    required String prefix,
  }) onGenerate;

  const BatchInitDialog({
    super.key,
    required this.station,
    required this.onGenerate,
  });

  @override
  State<BatchInitDialog> createState() => _BatchInitDialogState();
}

class _BatchInitDialogState extends State<BatchInitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _startIoaController = TextEditingController(text: '16385');
  final _countController = TextEditingController(text: '10');
  final _prefixController = TextEditingController(text: 'AnalogChannel');
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void dispose() {
    _startIoaController.dispose();
    _countController.dispose();
    _prefixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppI18n.instance.t('batchInit')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<AsduTypeId>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('pointType'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  AsduTypeId.mSpNa1,
                  AsduTypeId.mDpNa1,
                  AsduTypeId.mMeNc1,
                  AsduTypeId.mMeNa1,
                  AsduTypeId.mMeNb1,
                  AsduTypeId.mItNa1,
                ].map((t) => DropdownMenuItem(
                  value: t,
                  child: Text('Type ${t.id}: ${t.nameString} (${t.description})'),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedType = v;
                      if (v == AsduTypeId.mSpNa1) {
                        _startIoaController.text = '1001';
                        _prefixController.text = 'SwitchSP';
                      } else if (v == AsduTypeId.mDpNa1) {
                        _startIoaController.text = '2001';
                        _prefixController.text = 'SwitchDP';
                      } else if (v == AsduTypeId.mItNa1) {
                        _startIoaController.text = '25601';
                        _prefixController.text = 'MeterIT';
                      } else {
                        _startIoaController.text = '16385';
                        _prefixController.text = 'AnalogChannel';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startIoaController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('startAddr'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Valid positive integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('regQty'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0 || n > 500) return '1 ~ 500';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prefixController,
                decoration: InputDecoration(
                  labelText: AppI18n.instance.t('namePrefix'),
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
              final startIoa = int.parse(_startIoaController.text.trim());
              final count = int.parse(_countController.text.trim());
              final prefix = _prefixController.text.trim();

              widget.onGenerate(
                typeId: _selectedType,
                startIoa: startIoa,
                count: count,
                prefix: prefix,
              );
              Navigator.pop(context);
            }
          },
          child: Text(AppI18n.instance.t('batchInit')),
        ),
      ],
    );
  }
}
