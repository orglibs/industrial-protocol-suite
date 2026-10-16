import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/server_config.dart';

class EditServerDialog extends StatefulWidget {
  final ServerConfig config;
  final void Function(ServerConfig newConfig) onSaved;

  const EditServerDialog({
    super.key,
    required this.config,
    required this.onSaved,
  });

  @override
  State<EditServerDialog> createState() => _EditServerDialogState();
}

class _EditServerDialogState extends State<EditServerDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _dirCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.config.name);
    _ipCtrl = TextEditingController(text: widget.config.ip);
    _portCtrl = TextEditingController(text: widget.config.port.toString());
    _dirCtrl = TextEditingController(text: widget.config.fileTransferDirectory);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.config.name = _nameCtrl.text.trim();
    widget.config.ip = _ipCtrl.text.trim();
    widget.config.port = int.tryParse(_portCtrl.text.trim()) ?? 102;
    widget.config.fileTransferDirectory = _dirCtrl.text.trim();
    widget.onSaved(widget.config);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings),
          const SizedBox(width: 8),
          Text(i18n.t('editServerTitle')),
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
                  labelText: i18n.t('serverInstanceName'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.dns),
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
                        labelText: i18n.t('listenIp'),
                        hintText: i18n.t('listenIpHint'),
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
                        hintText: i18n.t('tcpPortHint'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        i18n.t('port102Help'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dirCtrl,
                decoration: InputDecoration(
                  labelText: i18n.t('mmsFileDirectory'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.folder_open),
                ),
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
          icon: const Icon(Icons.save),
          label: Text(i18n.t('saveSettings')),
          onPressed: _save,
        ),
      ],
    );
  }
}
