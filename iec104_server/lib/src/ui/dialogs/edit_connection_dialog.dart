import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../server/station.dart';

class EditConnectionDialog extends StatefulWidget {
  final Iec104ConnectionConfig? initialConfig;

  const EditConnectionDialog({super.key, this.initialConfig});

  @override
  State<EditConnectionDialog> createState() => _EditConnectionDialogState();
}

class _EditConnectionDialogState extends State<EditConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _t0Controller;
  late TextEditingController _t1Controller;
  late TextEditingController _t2Controller;
  late TextEditingController _t3Controller;
  late TextEditingController _kController;
  late TextEditingController _wController;
  late int _cotSize;
  late int _caSize;
  late int _ioaSize;

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameController = TextEditingController(text: c?.displayName ?? 'IEC 104 Connection');
    _hostController = TextEditingController(text: c?.host ?? '0.0.0.0');
    _portController = TextEditingController(text: (c?.port ?? 2404).toString());
    _t0Controller = TextEditingController(text: (c?.t0 ?? 30).toString());
    _t1Controller = TextEditingController(text: (c?.t1 ?? 15).toString());
    _t2Controller = TextEditingController(text: (c?.t2 ?? 10).toString());
    _t3Controller = TextEditingController(text: (c?.t3 ?? 20).toString());
    _kController = TextEditingController(text: (c?.k ?? 12).toString());
    _wController = TextEditingController(text: (c?.w ?? 8).toString());
    _cotSize = c?.cotSize ?? 2;
    _caSize = c?.caSize ?? 2;
    _ioaSize = c?.ioaSize ?? 3;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
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
          Icon(Icons.settings_ethernet, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.initialConfig == null ? i18n.t('newConnTitle') : i18n.t('editConnTitle'),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _hostController,
                        decoration: InputDecoration(
                          labelText: i18n.t('connHost'),
                          prefixIcon: const Icon(Icons.dns_outlined),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? i18n.t('connAliasRequired') : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: i18n.t('connPort'),
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          final p = int.tryParse(v ?? '');
                          if (p == null || p < 1 || p > 65535) return '1-65535';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  i18n.t('connAndParam'),
                  style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _t0Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 't0 (s)', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t1Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 't1 (s)', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t2Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 't2 (s)', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _t3Controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 't3 (s)', border: OutlineInputBorder(), isDense: true),
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
                        decoration: const InputDecoration(labelText: 'k (I frames)', border: OutlineInputBorder(), isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _wController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'w (I frames)', border: OutlineInputBorder(), isDense: true),
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
                        decoration: InputDecoration(labelText: i18n.t('cotSize'), border: const OutlineInputBorder(), isDense: true),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(i18n.t('byte1'))),
                          DropdownMenuItem(value: 2, child: Text(i18n.t('byte2Std'))),
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
                        decoration: InputDecoration(labelText: i18n.t('caSize'), border: const OutlineInputBorder(), isDense: true),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(i18n.t('byte1'))),
                          DropdownMenuItem(value: 2, child: Text(i18n.t('byte2Std'))),
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
                        decoration: InputDecoration(labelText: i18n.t('ioaSize'), border: const OutlineInputBorder(), isDense: true),
                        items: [
                          DropdownMenuItem(value: 2, child: Text(i18n.t('byte2'))),
                          DropdownMenuItem(value: 3, child: Text(i18n.t('byte3Std'))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _ioaSize = v);
                        },
                      ),
                    ),
                  ],
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
            if (_formKey.currentState?.validate() ?? false) {
              final newName = _nameController.text.trim();
              final host = _hostController.text.trim();
              final port = int.tryParse(_portController.text.trim()) ?? 2404;
              final t0 = int.tryParse(_t0Controller.text.trim()) ?? 30;
              final t1 = int.tryParse(_t1Controller.text.trim()) ?? 15;
              final t2 = int.tryParse(_t2Controller.text.trim()) ?? 10;
              final t3 = int.tryParse(_t3Controller.text.trim()) ?? 20;
              final k = int.tryParse(_kController.text.trim()) ?? 12;
              final w = int.tryParse(_wController.text.trim()) ?? 8;

              if (widget.initialConfig != null) {
                final c = widget.initialConfig!;
                c.name = newName;
                c.nameKey = null; // user customized
                c.host = host;
                c.port = port;
                c.t0 = t0;
                c.t1 = t1;
                c.t2 = t2;
                c.t3 = t3;
                c.k = k;
                c.w = w;
                c.cotSize = _cotSize;
                c.caSize = _caSize;
                c.ioaSize = _ioaSize;
                c.syncConfigToServer();
                c.notifyListeners();
                Navigator.of(context).pop(c);
              } else {
                final newConfig = Iec104ConnectionConfig(
                  name: newName,
                  host: host,
                  port: port,
                  t0: t0,
                  t1: t1,
                  t2: t2,
                  t3: t3,
                  k: k,
                  w: w,
                  cotSize: _cotSize,
                  caSize: _caSize,
                  ioaSize: _ioaSize,
                  stations: [
                    Station.createDefault(commonAddress: 1),
                  ],
                );
                Navigator.of(context).pop(newConfig);
              }
            }
          },
          child: Text(i18n.t('save')),
        ),
      ],
    );
  }
}
