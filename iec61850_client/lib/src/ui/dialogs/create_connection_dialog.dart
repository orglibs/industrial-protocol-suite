import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';

class CreateConnectionDialog extends StatefulWidget {
  final ConnectionConfig? initialConfig;
  final void Function(ConnectionConfig config) onSaved;

  const CreateConnectionDialog({
    super.key,
    this.initialConfig,
    required this.onSaved,
  });

  @override
  State<CreateConnectionDialog> createState() => _CreateConnectionDialogState();
}

class _CreateConnectionDialogState extends State<CreateConnectionDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _localTsapCtrl;
  late TextEditingController _remoteTsapCtrl;
  late bool _autoConnect;
  String? _selectedTemplate;

  static const List<({String titleKey, String filename, String path})> _templates = [
    (titleKey: 'tplBasicIoTitle', filename: 'server_example_basic_io.icd', path: 'assets/examples/server_example_basic_io.icd'),
    (titleKey: 'tplControlTitle', filename: 'server_example_control.icd', path: 'assets/examples/server_example_control.icd'),
    (titleKey: 'tplGooseTitle', filename: 'server_example_goose.icd', path: 'assets/examples/server_example_goose.icd'),
    (titleKey: 'tpl61400Title', filename: 'server_example_61400_25.icd', path: 'assets/examples/server_example_61400_25.icd'),
    (titleKey: 'tplSgTitle', filename: 'server_example_sg.icd', path: 'assets/examples/server_example_sg.icd'),
    (titleKey: 'tplSimpleTitle', filename: 'server_example_simple.icd', path: 'assets/examples/server_example_simple.icd'),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameCtrl = TextEditingController(text: c?.displayName ?? (c?.name ?? 'IEC 61850 Server Connection'));
    _ipCtrl = TextEditingController(text: c?.ip ?? '127.0.0.1');
    _portCtrl = TextEditingController(text: (c?.port ?? 102).toString());
    _localTsapCtrl = TextEditingController(text: '0x${(c?.localTsap ?? 0x0001).toRadixString(16).padLeft(4, '0')}');
    _remoteTsapCtrl = TextEditingController(text: '0x${(c?.remoteTsap ?? 0x0001).toRadixString(16).padLeft(4, '0')}');
    _autoConnect = c?.autoConnect ?? false;
    final initialPath = c?.boundSclPath;
    if (initialPath != null && initialPath.isNotEmpty) {
      if (_templates.any((t) => t.path == initialPath)) {
        _selectedTemplate = initialPath;
      } else {
        final match = _templates.where((t) => t.path.contains(initialPath) || t.filename.contains(initialPath)).firstOrNull;
        _selectedTemplate = match?.path ?? initialPath;
      }
    } else {
      _selectedTemplate = _templates.first.path;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _localTsapCtrl.dispose();
    _remoteTsapCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final id = widget.initialConfig?.id ?? 'conn_${DateTime.now().millisecondsSinceEpoch}';
    final port = int.tryParse(_portCtrl.text.trim()) ?? 102;
    int localTsap = 0x0001;
    int remoteTsap = 0x0001;

    try {
      final lStr = _localTsapCtrl.text.replaceAll('0x', '').replaceAll('0X', '');
      localTsap = int.parse(lStr, radix: 16);
    } catch (_) {}

    try {
      final rStr = _remoteTsapCtrl.text.replaceAll('0x', '').replaceAll('0X', '');
      remoteTsap = int.parse(rStr, radix: 16);
    } catch (_) {}

    final newName = _nameCtrl.text.trim();
    final originalName = widget.initialConfig?.name;
    final originalDisplayName = widget.initialConfig?.displayName;
    final bool nameUnchanged = widget.initialConfig != null &&
        (newName == originalName || newName == originalDisplayName);

    String? assignedNameKey;
    if (widget.initialConfig != null) {
      assignedNameKey = nameUnchanged ? widget.initialConfig!.nameKey : null;
    } else {
      final defaultName = 'IEC 61850 Server Connection';
      final isDefaultOrTemplate = newName.isEmpty ||
          newName == defaultName ||
          newName == AppI18n.instance.t('preset_iec61850_client_conn') ||
          _templates.any((t) => newName == AppI18n.instance.t(t.titleKey));
      if (isDefaultOrTemplate) {
        if (_selectedTemplate?.contains('basic_io') == true) {
          assignedNameKey = 'preset_conn_basic_io';
        } else if (_selectedTemplate?.contains('control') == true) {
          assignedNameKey = 'preset_conn_control';
        } else if (_selectedTemplate?.contains('goose') == true) {
          assignedNameKey = 'preset_conn_goose';
        } else {
          assignedNameKey = 'preset_iec61850_client_conn';
        }
      }
    }

    final cfg = ConnectionConfig(
      id: id,
      name: newName,
      nameKey: assignedNameKey,
      ip: _ipCtrl.text.trim(),
      port: port,
      localTsap: localTsap,
      remoteTsap: remoteTsap,
      boundSclPath: _selectedTemplate,
      autoConnect: _autoConnect,
    );

    widget.onSaved(cfg);
    Navigator.of(context).pop();
  }

  bool get isEdit => widget.initialConfig != null;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add_link),
          const SizedBox(width: 8),
          Text(isEdit ? i18n.t('editConnTitle') : i18n.t('createConnTitle')),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: i18n.t('connAlias'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipCtrl,
                      decoration: InputDecoration(
                        labelText: i18n.t('remoteIp'),
                        hintText: '127.0.0.1 / 192.168.1.100',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: i18n.t('tcpPort'),
                        hintText: '102 / 10102',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _localTsapCtrl,
                      decoration: InputDecoration(
                        labelText: i18n.t('localTsap'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _remoteTsapCtrl,
                      decoration: InputDecoration(
                        labelText: i18n.t('remoteTsap'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: _selectedTemplate,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: i18n.t('bindSclModel'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.description),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(i18n.t('noOfflineModel')),
                  ),
                  ..._templates.map((t) {
                    return DropdownMenuItem<String?>(
                      value: t.path,
                      child: Text('${t.filename} (${i18n.t(t.titleKey)})', overflow: TextOverflow.ellipsis),
                    );
                  }),
                  if (_selectedTemplate != null && !_templates.any((t) => t.path == _selectedTemplate))
                    DropdownMenuItem<String?>(
                      value: _selectedTemplate,
                      child: Text('$_selectedTemplate', overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (val) {
                  setState(() => _selectedTemplate = val);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i18n.t('autoConnectLabel')),
                value: _autoConnect,
                onChanged: (val) => setState(() => _autoConnect = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.t('cancel')),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: Text(isEdit ? i18n.t('saveChangesBtn') : i18n.t('createConnBtn')),
          onPressed: _save,
        ),
      ],
    );
  }
}
