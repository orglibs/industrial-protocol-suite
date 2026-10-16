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
      setState(() => _errorMsg = '请输入有效的数值 (支持十进制、0x十六进制)');
      return;
    }

    if (parsedVal < -32768 || parsedVal > 65535) {
      setState(() => _errorMsg = '数值超出16位寄存器范围 (-32768 ~ 65535)');
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
        setState(() => _errorMsg = '写入失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.edit_note, color: Colors.blue),
          SizedBox(width: 8),
          Text('FC 06: 写单个保持寄存器 (Write Single Register)'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('从站 Unit ID: ${widget.slaveId}  |  寄存器地址: ${widget.address} (0x${widget.address.toRadixString(16).padLeft(4, "0").toUpperCase()})'),
            const SizedBox(height: 16),
            TextField(
              controller: _valCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '输入写入值 (十进制 或 0x十六进制)',
                hintText: '如 1234 或 0x04D2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 8),
            Text(
              '提示: 支持无符号 0..65535 或 有符号 -32768..32767',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _send,
          child: _isSending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('立即写入'),
        ),
      ],
    );
  }
}
