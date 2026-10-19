import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/server_config.dart';

class EditServerDialog extends StatefulWidget {
  final ServerConfig? config;
  final void Function(ServerConfig newConfig) onSaved;
  final VoidCallback? onDelete;

  const EditServerDialog({
    super.key,
    this.config,
    required this.onSaved,
    this.onDelete,
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
    final c = widget.config;
    _nameCtrl = TextEditingController(text: c != null ? c.displayName : 'IEC 61850 MMS Server');
    _ipCtrl = TextEditingController(text: c?.ip ?? '0.0.0.0');
    _portCtrl = TextEditingController(text: (c?.port ?? 102).toString());
    _dirCtrl = TextEditingController(text: c?.fileTransferDirectory ?? '');
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
    final cfg = widget.config ?? ServerConfig();
    cfg.nameKey = null;
    cfg.name = _nameCtrl.text.trim();
    cfg.ip = _ipCtrl.text.trim();
    cfg.port = int.tryParse(_portCtrl.text.trim()) ?? 102;
    if (_dirCtrl.text.trim().isNotEmpty) {
      cfg.fileTransferDirectory = _dirCtrl.text.trim();
    }
    widget.onSaved(cfg);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isNew = widget.config == null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isNew ? Icons.add_circle_outline : Icons.settings),
          const SizedBox(width: 8),
          Text(isNew ? i18n.t('newConn') : i18n.t('editServerTitle')),
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
        if (widget.onDelete != null)
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(i18n.t('deleteConn')),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call();
            },
          ),
        const Spacer(),
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
