import 'package:flutter/material.dart';
import '../../protocol/modbus_client.dart';

class WriteMultipleRegistersDialog extends StatefulWidget {
  final ModbusClient client;
  final int slaveId;
  final int startAddress;
  final List<int>? initialValues;

  const WriteMultipleRegistersDialog({
    super.key,
    required this.client,
    required this.slaveId,
    required this.startAddress,
    this.initialValues,
  });

  static Future<bool?> show(
    BuildContext context, {
    required ModbusClient client,
    required int slaveId,
    required int startAddress,
    List<int>? initialValues,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => WriteMultipleRegistersDialog(
        client: client,
        slaveId: slaveId,
        startAddress: startAddress,
        initialValues: initialValues,
      ),
    );
  }

  @override
  State<WriteMultipleRegistersDialog> createState() => _WriteMultipleRegistersDialogState();
}

class _WriteMultipleRegistersDialogState extends State<WriteMultipleRegistersDialog> {
  late TextEditingController _addrCtrl;
  late TextEditingController _valuesCtrl;
  bool _isSending = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _addrCtrl = TextEditingController(text: widget.startAddress.toString());
    final initialList = widget.initialValues ?? [100, 200, 300];
    _valuesCtrl = TextEditingController(text: initialList.join(', '));
  }

  @override
  void dispose() {
    _addrCtrl.dispose();
    _valuesCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final addr = int.tryParse(_addrCtrl.text.trim());
    if (addr == null || addr < 0 || addr > 65535) {
      setState(() => _errorMsg = '请输入有效的起始地址 (0..65535)');
      return;
    }

    final rawText = _valuesCtrl.text.trim();
    final tokens = rawText.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
    if (tokens.isEmpty) {
      setState(() => _errorMsg = '请输入至少一个寄存器数值');
      return;
    }

    final List<int> values = [];
    for (var tok in tokens) {
      int? v;
      if (tok.startsWith('0x') || tok.startsWith('0X')) {
        v = int.tryParse(tok.substring(2), radix: 16);
      } else {
        v = int.tryParse(tok);
      }
      if (v == null) {
        setState(() => _errorMsg = '解析数值失败: "$tok"');
        return;
      }
      values.add(v & 0xFFFF);
    }

    if (values.length > 123) {
      setState(() => _errorMsg = 'Modbus单次最大支持写入123个寄存器');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMsg = null;
    });

    try {
      await widget.client.writeMultipleRegisters(
        unitId: widget.slaveId,
        startAddress: addr,
        values: values,
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
          Icon(Icons.playlist_add_check, color: Colors.deepPurple),
          SizedBox(width: 8),
          Text('FC 16: 写多个保持寄存器 (Write Multiple Registers)'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('从站 Unit ID: ${widget.slaveId}'),
            const SizedBox(height: 12),
            TextField(
              controller: _addrCtrl,
              decoration: const InputDecoration(
                labelText: '起始寄存器地址 (Start Address)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valuesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '写入数值列表 (逗号或空格分隔)',
                hintText: '如: 100, 200, 0x1A2B, 450',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '提示: 支持十进制与十六进制混合输入，一次性批量写入连续寄存器',
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
              : const Text('批量写入'),
        ),
      ],
    );
  }
}
