import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../protocol/asdu.dart';

class BatchAddPointsDialog extends StatefulWidget {
  final ClientStationModel station;
  final VoidCallback? onGenerated;

  const BatchAddPointsDialog({
    super.key,
    required this.station,
    this.onGenerated,
  });

  @override
  State<BatchAddPointsDialog> createState() => _BatchAddPointsDialogState();
}

class _BatchAddPointsDialogState extends State<BatchAddPointsDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _startIoaCtrl;
  late TextEditingController _countCtrl;
  late TextEditingController _prefixCtrl;
  AsduTypeId _selectedType = AsduTypeId.mMeNc1;
  bool _overwriteExisting = true;

  @override
  void initState() {
    super.initState();
    _startIoaCtrl = TextEditingController(text: '16385');
    _countCtrl = TextEditingController(text: '16');
    _prefixCtrl = TextEditingController(text: 'Analog #');
  }

  @override
  void dispose() {
    _startIoaCtrl.dispose();
    _countCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  void _onTypeChanged(AsduTypeId? type) {
    if (type == null) return;
    setState(() {
      _selectedType = type;
      if (type == AsduTypeId.mSpNa1) {
        _startIoaCtrl.text = '1';
        _prefixCtrl.text = 'Switch #';
      } else if (type == AsduTypeId.mDpNa1) {
        _startIoaCtrl.text = '1001';
        _prefixCtrl.text = 'Disconnector #';
      } else if (type == AsduTypeId.mItNa1) {
        _startIoaCtrl.text = '25601';
        _prefixCtrl.text = 'Meter #';
      } else if (type == AsduTypeId.mMeNa1) {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = 'Normalized #';
      } else if (type == AsduTypeId.mMeNb1) {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = 'Scaled #';
      } else {
        _startIoaCtrl.text = '16385';
        _prefixCtrl.text = 'Float #';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.playlist_add, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text('${i18n.t('batchAddPoints')} (COA: ${widget.station.commonAddress})'),
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
                  i18n.t('batchAddPrompt'),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
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
                    DropdownMenuItem(value: AsduTypeId.mDpNa1, child: Text('Type 3: M_DP_NA_1 (Double Point)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNc1, child: Text('Type 13: M_ME_NC_1 (Short Float)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNa1, child: Text('Type 9: M_ME_NA_1 (Normalized)')),
                    DropdownMenuItem(value: AsduTypeId.mMeNb1, child: Text('Type 11: M_ME_NB_1 (Scaled)')),
                    DropdownMenuItem(value: AsduTypeId.mItNa1, child: Text('Type 15: M_IT_NA_1 (Energy Counter)')),
                  ],
                  onChanged: _onTypeChanged,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _startIoaCtrl,
                        decoration: InputDecoration(
                          labelText: i18n.t('startIoa'),
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
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _countCtrl,
                        decoration: InputDecoration(
                          labelText: i18n.t('pointCount'),
                          helperText: '1 ~ 2000',
                          prefixIcon: const Icon(Icons.format_list_numbered),
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0 || n > 2000) {
                            return '1 ~ 2000';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _prefixCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.t('namePrefix'),
                    prefixIcon: const Icon(Icons.drive_file_rename_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return i18n.t('valRequired');
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Overwrite existing points', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Replace existing points if IOA already exists', style: TextStyle(fontSize: 12)),
                  value: _overwriteExisting,
                  onChanged: (val) => setState(() => _overwriteExisting = val),
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
          icon: const Icon(Icons.bolt, size: 18),
          label: Text(i18n.t('confirm')),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final startIoa = int.parse(_startIoaCtrl.text.trim());
              final count = int.parse(_countCtrl.text.trim());
              final prefix = _prefixCtrl.text.trim();

              int addedCount = 0;
              for (int i = 0; i < count; i++) {
                final ioa = startIoa + i;
                if (!_overwriteExisting && widget.station.getPoint(ioa) != null) {
                  continue;
                }

                dynamic val;
                if (_selectedType == AsduTypeId.mSpNa1) {
                  val = false;
                } else if (_selectedType == AsduTypeId.mDpNa1) {
                  val = 1;
                } else if (_selectedType == AsduTypeId.mMeNc1) {
                  val = 0.0;
                } else {
                  val = 0;
                }

                widget.station.addPoint(ClientPointModel(
                  commonAddress: widget.station.commonAddress,
                  ioa: ioa,
                  typeId: _selectedType,
                  name: '$prefix #${i + 1}',
                  value: val,
                ));
                addedCount++;
              }

              Navigator.pop(context);
              widget.onGenerated?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${i18n.t('batchAddPoints')}: $addedCount'),
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
