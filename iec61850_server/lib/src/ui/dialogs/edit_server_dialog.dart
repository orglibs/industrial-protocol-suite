import 'package:flutter/material.dart';
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
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings),
          SizedBox(width: 8),
          Text('IEC 61850 服务器配置'),
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
                decoration: const InputDecoration(
                  labelText: '服务器实例名称',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.dns),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _ipCtrl,
                      decoration: const InputDecoration(
                        labelText: '监听 IP 地址',
                        hintText: '0.0.0.0 或 127.0.0.1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'TCP 端口',
                        hintText: '102 (或 10102)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
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
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提示：IEC 61850 MMS 协议标准端口为 102。在 Linux 系统下，非 root 运行需超级权限；普通用户测试可将端口改为 10102 或 15502。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _dirCtrl,
                decoration: const InputDecoration(
                  labelText: 'MMS 文件传输工作目录 (File Services)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_open),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('保存设置'),
          onPressed: _save,
        ),
      ],
    );
  }
}
