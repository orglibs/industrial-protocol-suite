import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../protocol/modbus_client.dart';

class WriteSingleRegisterDialog extends StatefulWidget {
  final ModbusClient client;
  final int slaveId;
  final int address;
  final int initialValue;

  const WriteSingleRegisterDialog({
    super.key,
    required this.client,
    required this.slaveId,
    required this.address,
    this.initialValue = 0,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ModbusClient client,
    required int slaveId,
    required int address,
    int initialValue = 0,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => WriteSingleRegisterDialog(
        client: client,
        slaveId: slaveId,
        address: address,
        initialValue: initialValue,
      ),
    );
  }

  @override
  State<WriteSingleRegisterDialog> createState() => _WriteSingleRegisterDialogState();
}

class _WriteSingleRegisterDialogState extends State<WriteSingleRegisterDialog> {
  final TextEditingController _valCtrl = TextEditingController();
  bool _isSending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _valCtrl.text = widget.initialValue.toString();
  }

  @override
  void dispose() {
    _valCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _valCtrl.text.trim();
    int? parsedVal;

    if (text.startsWith('0x') || text.startsWith('0X')) {
      parsedVal = int.tryParse(text.substring(2), radix: 16);
    } else if (text.startsWith('0b') || text.startsWith('0B')) {
      parsedVal = int.tryParse(text.substring(2), radix: 2);
    } else {
      parsedVal = int.tryParse(text);
    }

    if (parsedVal == null) {
      setState(() => _errorMsg = AppI18n.instance.t('valRequired'));
      return;
    }

    if (parsedVal < -32768 || parsedVal > 65535) {
      setState(() => _errorMsg = 'Range: -32768 ~ 65535');
      return;
    }

    final regVal = parsedVal & 0xFFFF;

    setState(() {
      _isSending = true;
      _errorMsg = null;
    });

    try {
      await widget.client.writeSingleRegister(
        unitId: widget.slaveId,
        address: widget.address,
        value: regVal,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = '${AppI18n.instance.t('parseError')}: $e');
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

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_note, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppI18n.instance.t('writeSingleRegister'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppI18n.instance.t('slaveId')}: ${widget.slaveId}  |  ${AppI18n.instance.t('colAddr')}: ${widget.address}'),
            const SizedBox(height: 16),
            TextField(
              controller: _valCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppI18n.instance.t('inputNum'),
                hintText: '1234 | 0x04D2',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.numbers),
              ),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 8),
            Text(
              '0..65535 | -32768..32767',
              style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
            ),
            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
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
