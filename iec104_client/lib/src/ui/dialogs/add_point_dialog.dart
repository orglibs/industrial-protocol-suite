import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../protocol/asdu.dart';

class AddPointDialog extends StatefulWidget {
  final ClientStationModel station;
  final void Function(ClientPointModel newPoint)? onAdded;

  const AddPointDialog({
    super.key,
    required this.station,
    this.onAdded,
  });

  @override
  State<AddPointDialog> createState() => _AddPointDialogState();
}

class _AddPointDialogState extends State<AddPointDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ioaCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _valCtrl;
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;

  @override
  void initState() {
    super.initState();
    // Default IOA to max existing IOA + 1 or 1
    int nextIoa = 1;
    if (widget.station.points.isNotEmpty) {
      nextIoa = widget.station.points.keys.reduce((a, b) => a > b ? a : b) + 1;
    }
    _ioaCtrl = TextEditingController(text: nextIoa.toString());
    _nameCtrl = TextEditingController(text: 'Channel #$nextIoa');
    _valCtrl = TextEditingController(text: '0.0');
  }

  @override
  void dispose() {
    _ioaCtrl.dispose();
    _nameCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(AsduTypeId? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      final ioaStr = _ioaCtrl.text.trim();
      if (type == AsduTypeId.mSpNa1 || type == AsduTypeId.mSpTb1) {
        _nameCtrl.text = 'SP #$ioaStr';
        _valCtrl.text = 'false';
      } else if (type == AsduTypeId.mDpNa1 || type == AsduTypeId.mDpTb1) {
        _nameCtrl.text = 'DP #$ioaStr';
        _valCtrl.text = '1';
      } else if (type == AsduTypeId.mItNa1 || type == AsduTypeId.mItTb1) {
        _nameCtrl.text = 'Energy #$ioaStr';
        _valCtrl.text = '0';
      } else if (type == AsduTypeId.mStNa1 || type == AsduTypeId.mStTb1) {
        _nameCtrl.text = 'Tap #$ioaStr';
        _valCtrl.text = '0';
      } else if (type == AsduTypeId.mBoNa1 || type == AsduTypeId.mBoTb1) {
        _nameCtrl.text = 'Bits #$ioaStr';
        _valCtrl.text = '0';
      } else {
        _nameCtrl.text = 'ME #$ioaStr';
        _valCtrl.text = '0.0';
      }
    });
  }

  dynamic _parseValue() {
    final text = _valCtrl.text.trim();
    if (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1) {
      return text == '1' || text.toLowerCase() == 'true';
    } else if (_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1) {
      return int.tryParse(text) ?? 1;
    } else if (_selectedType == AsduTypeId.mMeNc1 || _selectedType == AsduTypeId.mMeTf1) {
      return double.tryParse(text) ?? 0.0;
    } else {
      return int.tryParse(text) ?? (double.tryParse(text)?.toInt() ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('${i18n.t('addPoint')} (COA: ${widget.station.commonAddress})'),
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
                TextFormField(
                  controller: _ioaCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('ioa'),
                    helperText: '1 ~ 16777215',
                    prefixIcon: const Icon(Icons.pin),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0 || n > 16777215) {
                      return '1 ~ 16777215';
                    }
                    if (widget.station.getPoint(n) != null) {
                      return 'IOA=$n already exists';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AsduTypeId>(
                  initialValue: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ASDU Type',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: AsduTypeId.mSpNa1, child: Text('Type 1: M_SP_NA_1 (Single Point)')),
                    DropdownMenuItem(value: AsduTypeId.mSpTb1, child: Text('Type 30: M_SP_TB_1 (Single Point CP56)')),
                    DropdownMenuItem(value: AsduTypeId.mDpNa1, child: Text('Type 3: M_DP_NA_1 (Double Point)')),
                    DropdownMenuItem(value: AsduTypeId.mDpTb1, child: Text('Type 31: M_DP_TB_1 (Double Point CP56)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNc1, child: Text('Type 13: M_ME_NC_1 (Short Float)')),
                    DropdownMenuItem(value: AsduTypeId.mMeTf1, child: Text('Type 36: M_ME_TF_1 (Short Float CP56)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNa1, child: Text('Type 9: M_ME_NA_1 (Normalized)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNb1, child: Text('Type 11: M_ME_NB_1 (Scaled)')),
                    DropdownMenuItem(value: AsduTypeId.mItNa1, child: Text('Type 15: M_IT_NA_1 (Energy Counter)')),
                    DropdownMenuItem(value: AsduTypeId.mStNa1, child: Text('Type 5: M_ST_NA_1 (Step Position)')),
                    DropdownMenuItem(value: AsduTypeId.mBoNa1, child: Text('Type 7: M_BO_NA_1 (32-Bitstring)')),
                  ],
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 16),
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
                    helperText: (_selectedType == AsduTypeId.mSpNa1 || _selectedType == AsduTypeId.mSpTb1)
                        ? '1 (ON/true) | 0 (OFF/false)'
                        : ((_selectedType == AsduTypeId.mDpNa1 || _selectedType == AsduTypeId.mDpTb1)
                            ? '2 (ON), 1 (OFF), 0/3 (Indeterminate)'
                            : 'Float / Integer'),
                    prefixIcon: const Icon(Icons.numbers),
                    border: const OutlineInputBorder(),
                  ),
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
              final ioa = int.parse(_ioaCtrl.text.trim());
              final name = _nameCtrl.text.trim();
              final val = _parseValue();

              final newPoint = ClientPointModel(
                commonAddress: widget.station.commonAddress,
                ioa: ioa,
                typeId: _selectedType,
                name: name,
                value: val,
              );

              widget.station.addPoint(newPoint);
              Navigator.pop(context);
              widget.onAdded?.call(newPoint);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${i18n.t('addPoint')}: $name (IOA: $ioa)'),
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
