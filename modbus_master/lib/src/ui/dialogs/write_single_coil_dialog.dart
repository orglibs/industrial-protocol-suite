import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../protocol/modbus_client.dart';

class WriteSingleCoilDialog extends StatefulWidget {
  final ModbusClient client;
  final int slaveId;
  final int address;
  final bool initialValue;

  const WriteSingleCoilDialog({
    super.key,
    required this.client,
    required this.slaveId,
    required this.address,
    this.initialValue = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ModbusClient client,
    required int slaveId,
    required int address,
    bool initialValue = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => WriteSingleCoilDialog(
        client: client,
        slaveId: slaveId,
        address: address,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<WriteSingleCoilDialog> createState() => _WriteSingleCoilDialogState();
}

class _WriteSingleCoilDialogState extends State<WriteSingleCoilDialog> {
  late int _slaveId;
  late int _address;
  late bool _value;
  bool _isSending = false;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    _slaveId = widget.slaveId;
    _address = widget.address;
    _value = widget.initialValue;
  }

  Future<void> _send() async {
    setState(() {
      _isSending = true;
      _statusMsg = null;
    });

    try {
      await widget.client.writeSingleCoil(
        unitId: _slaveId,
        address: _address,
        value: _value,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMsg = '${AppI18n.instance.t('parseError')}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.toggle_on, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppI18n.instance.t('writeSingleCoil'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppI18n.instance.t('slaveId')}: $_slaveId  |  ${AppI18n.instance.t('colAddr')}: $_address'),
            const SizedBox(height: 16),
            Text('${AppI18n.instance.t('currValue')}:'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _value ? Colors.green.shade600 : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      foregroundColor: _value ? Colors.white : theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: Text('${AppI18n.instance.t('on')} (0xFF00)'),
                    onPressed: () => setState(() => _value = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_value ? Colors.red.shade600 : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      foregroundColor: !_value ? Colors.white : theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.cancel),
                    label: Text('${AppI18n.instance.t('off')} (0x0000)'),
                    onPressed: () => setState(() => _value = false),
                  ),
                ),
              ],
            ),
            if (_statusMsg != null) ...[
              const SizedBox(height: 12),
              Text(_statusMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppI18n.instance.t('cancel')),
        ),
        FilledButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppI18n.instance.t('confirm')),
        ),
      ],
    );
  }
}
