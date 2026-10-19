import 'package:flutter/material.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';

class EditConnectionDialog extends StatefulWidget {
  final Iec104ClientConnectionConfig? connection;
  final int defaultIndex;

  const EditConnectionDialog({
    super.key,
    this.connection,
    this.defaultIndex = 1,
  });

  static Future<Iec104ClientConnectionConfig?> show(
    BuildContext context, {
    Iec104ClientConnectionConfig? connection,
    int defaultIndex = 1,
  }) {
    return showDialog<Iec104ClientConnectionConfig>(
      context: context,
      builder: (_) => EditConnectionDialog(
        connection: connection,
        defaultIndex: defaultIndex,
      ),
    );
  }

  @override
  State<EditConnectionDialog> createState() => _EditConnectionDialogState();
}

class _EditConnectionDialogState extends State<EditConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _caController;
  late TextEditingController _t0Controller;
  late TextEditingController _t1Controller;
  late TextEditingController _t2Controller;
  late TextEditingController _t3Controller;
  late TextEditingController _kController;
  late TextEditingController _wController;
  late int _cotSize;
  late int _caSize;
  late int _ioaSize;
  late bool _autoStartDt;
  late bool _autoGeneralInterrogation;

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _nameController = TextEditingController(
      text: c?.displayName ?? 'Connection ${widget.defaultIndex}',
    );
    _hostController = TextEditingController(text: c?.host ?? '127.0.0.1');
    _portController = TextEditingController(text: (c?.port ?? 2404).toString());
    _caController = TextEditingController(text: (c?.defaultCa ?? 1).toString());
    _t0Controller = TextEditingController(text: (c?.t0 ?? 30).toString());
    _t1Controller = TextEditingController(text: (c?.t1 ?? 15).toString());
    _t2Controller = TextEditingController(text: (c?.t2 ?? 10).toString());
    _t3Controller = TextEditingController(text: (c?.t3 ?? 20).toString());
    _kController = TextEditingController(text: (c?.k ?? 12).toString());
    _wController = TextEditingController(text: (c?.w ?? 8).toString());
    _cotSize = c?.cotSize ?? 2;
    _caSize = c?.caSize ?? 2;
    _ioaSize = c?.ioaSize ?? 3;
    _autoStartDt = c?.autoStartDt ?? true;
    _autoGeneralInterrogation = c?.autoGeneralInterrogation ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _caController.dispose();
    _t0Controller.dispose();
    _t1Controller.dispose();
    _t2Controller.dispose();
    _t3Controller.dispose();
    _kController.dispose();
    _wController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.hub, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.connection == null ? i18n.t('newConnTitle') : i18n.t('editConnTitle'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: i18n.t('connAlias'),
                    hintText: i18n.t('connAliasHint'),
                    prefixIcon: const Icon(Icons.label_outline),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? i18n.t('connAliasRequired') : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          labelText: i18n.t('targetIp'),
                          prefixIcon: const Icon(Icons.computer),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: i18n.t('port'),
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          final val = int.tryParse(v ?? '');
                          if (val == null || val <= 0 || val > 65535) {
                            return '1-65535';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n.t('defaultCa'),
                    prefixIcon: const Icon(Icons.dns),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) {
                    final val = int.tryParse(v ?? '');
                    if (val == null || val <= 0 || val > 65535) {
                      return '1-65535';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  i18n.t('networkTimers'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _t0Controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 't0 (${i18n.t('connTimeout')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t1Controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 't1 (${i18n.t('ackTimeout')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t2Controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 't2 (${i18n.t('sFrameAckDelay')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t3Controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 't3 (${i18n.t('heartbeat')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _kController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'k (${i18n.t('kValue')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _wController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'w (${i18n.t('wValue')})',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _cotSize,
                        decoration: InputDecoration(
                          labelText: i18n.t('cotSize'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Byte')),
                          DropdownMenuItem(value: 2, child: Text('2 Bytes')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _cotSize = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _caSize,
                        decoration: InputDecoration(
                          labelText: i18n.t('caSize'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Byte')),
                          DropdownMenuItem(value: 2, child: Text('2 Bytes')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _caSize = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _ioaSize,
                        decoration: InputDecoration(
                          labelText: i18n.t('ioaSize'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 Byte')),
                          DropdownMenuItem(value: 2, child: Text('2 Bytes')),
                          DropdownMenuItem(value: 3, child: Text('3 Bytes')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _ioaSize = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i18n.t('autoStartdt')),
                  value: _autoStartDt,
                  onChanged: (v) => setState(() => _autoStartDt = v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i18n.t('autoGeneralInterrogation')),
                  value: _autoGeneralInterrogation,
                  onChanged: (v) => setState(() => _autoGeneralInterrogation = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.t('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final targetCa = int.tryParse(_caController.text.trim()) ?? 1;

            if (widget.connection != null) {
              final c = widget.connection!;
              c.name = _nameController.text.trim();
              c.nameKey = null; // custom name override
              c.host = _hostController.text.trim();
              c.port = int.parse(_portController.text.trim());
              c.defaultCa = targetCa;
              c.t0 = int.tryParse(_t0Controller.text.trim()) ?? c.t0;
              c.t1 = int.tryParse(_t1Controller.text.trim()) ?? c.t1;
              c.t2 = int.tryParse(_t2Controller.text.trim()) ?? c.t2;
              c.t3 = int.tryParse(_t3Controller.text.trim()) ?? c.t3;
              c.k = int.tryParse(_kController.text.trim()) ?? c.k;
              c.w = int.tryParse(_wController.text.trim()) ?? c.w;
              c.cotSize = _cotSize;
              c.caSize = _caSize;
              c.ioaSize = _ioaSize;
              c.autoStartDt = _autoStartDt;
              c.autoGeneralInterrogation = _autoGeneralInterrogation;
              c.syncConfigToClient();
              c.notifyListeners();
              Navigator.of(context).pop(c);
            } else {
              final defaultStation = ClientStationModel(
                commonAddress: targetCa,
                name: 'Station #$targetCa',
                nameKey: targetCa == 1 ? 'preset_station_110kv' : null,
              );
              defaultStation.applyTemplate('distribution');

              final newConfig = Iec104ClientConnectionConfig(
                name: _nameController.text.trim(),
                host: _hostController.text.trim(),
                port: int.parse(_portController.text.trim()),
                defaultCa: targetCa,
                t0: int.tryParse(_t0Controller.text.trim()) ?? 30,
                t1: int.tryParse(_t1Controller.text.trim()) ?? 15,
                t2: int.tryParse(_t2Controller.text.trim()) ?? 10,
                t3: int.tryParse(_t3Controller.text.trim()) ?? 20,
                k: int.tryParse(_kController.text.trim()) ?? 12,
                w: int.tryParse(_wController.text.trim()) ?? 8,
                cotSize: _cotSize,
                caSize: _caSize,
                ioaSize: _ioaSize,
                autoStartDt: _autoStartDt,
                autoGeneralInterrogation: _autoGeneralInterrogation,
                stations: [defaultStation],
              );
              Navigator.of(context).pop(newConfig);
            }
          },
          child: Text(i18n.t('confirm')),
        ),
      ],
    );
  }
}
