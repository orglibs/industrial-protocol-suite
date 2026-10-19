import '../../i18n/app_i18n.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../protocol/modbus_client.dart';
import '../../protocol/modbus_pdu.dart';

class CommandsTab extends StatefulWidget {
  final ModbusClient client;
  final ConnectionConfig config;

  const CommandsTab({
    super.key,
    required this.client,
    required this.config,
  });

  @override
  State<CommandsTab> createState() => _CommandsTabState();
}

class _CommandsTabState extends State<CommandsTab> {
  int _selectedFc = 3;
  late TextEditingController _unitIdCtrl;
  final TextEditingController _addrCtrl = TextEditingController(text: '0');
  final TextEditingController _qtyCtrl = TextEditingController(text: '10');
  final TextEditingController _valCtrl = TextEditingController(text: '1234');
  final TextEditingController _multiValsCtrl = TextEditingController(text: '100, 200, 300, 400');
  final TextEditingController _andMaskCtrl = TextEditingController(text: '0xFFFF');
  final TextEditingController _orMaskCtrl = TextEditingController(text: '0x0001');

  bool _coilBoolVal = true;
  bool _isExecuting = false;
  String? _executionResult;
  bool _isResultError = false;
  int _executionLatencyMs = 0;

  @override
  void initState() {
    super.initState();
    final initialId = widget.config.slaves.isNotEmpty ? widget.config.slaves.first.slaveId : 1;
    _unitIdCtrl = TextEditingController(text: initialId.toString());
  }

  @override
  void dispose() {
    _unitIdCtrl.dispose();
    _addrCtrl.dispose();
    _qtyCtrl.dispose();
    _valCtrl.dispose();
    _multiValsCtrl.dispose();
    _andMaskCtrl.dispose();
    _orMaskCtrl.dispose();
    super.dispose();
  }

  int _parseNumber(String text, [int defaultVal = 0]) {
    final t = text.trim();
    if (t.startsWith('0x') || t.startsWith('0X')) {
      return int.tryParse(t.substring(2), radix: 16) ?? defaultVal;
    }
    return int.tryParse(t) ?? defaultVal;
  }

  Future<void> _executeCommand() async {
    final unitId = int.tryParse(_unitIdCtrl.text.trim()) ?? 1;
    final addr = _parseNumber(_addrCtrl.text);
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;

    setState(() {
      _isExecuting = true;
      _executionResult = null;
      _isResultError = false;
    });

    final sw = Stopwatch()..start();
    try {
      String resultStr = '';
      switch (_selectedFc) {
        case 1: // FC 01: Read Coils
          final bits = await widget.client.readCoils(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final bitLines = bits.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value ? "ON (1)" : "OFF (0)"}').join('\n');
          resultStr = "[FC01 Read Coils OK]\nUnit: $unitId, Addr: $addr, Qty: $qty\n$bitLines";
          break;

        case 2: // FC 02: Read Discrete Inputs
          final bits = await widget.client.readDiscreteInputs(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final discLines = bits.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value ? "1" : "0"}').join('\n');
          resultStr = "[FC02 Read Discrete Inputs OK]\nUnit: $unitId, Addr: $addr, Qty: $qty\n$discLines";
          break;

        case 3: // FC 03: Read Holding Registers
          final words = await widget.client.readHoldingRegisters(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final holdLines = words.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value} (0x${e.value.toRadixString(16).padLeft(4, "0").toUpperCase()})').join('\n');
          resultStr = "[FC03 Read Holding Registers OK]\nUnit: $unitId, Addr: $addr, Qty: $qty\n$holdLines";
          break;

        case 4: // FC 04: Read Input Registers
          final words = await widget.client.readInputRegisters(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final inputLines = words.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value} (0x${e.value.toRadixString(16).padLeft(4, "0").toUpperCase()})').join('\n');
          resultStr = "[FC04 Read Input Registers OK]\nUnit: $unitId, Addr: $addr, Qty: $qty\n$inputLines";
          break;


        case 5: // FC 05: Write Single Coil
          await widget.client.writeSingleCoil(unitId: unitId, address: addr, value: _coilBoolVal);
          sw.stop();
          resultStr = "[FC05 Write Single Coil OK]\n";
          resultStr += "Unit: $unitId, Addr: $addr, Val: ${_coilBoolVal ? 'ON' : 'OFF'}";
          break;

        case 6: // FC 06: Write Single Register
          final val = _parseNumber(_valCtrl.text);
          await widget.client.writeSingleRegister(unitId: unitId, address: addr, value: val & 0xFFFF);
          sw.stop();
          resultStr = "[FC06 Write Single Register OK]\n";
          resultStr += "Unit: $unitId, Addr: $addr, Val: $val";
          break;

        case 15: // FC 15: Write Multiple Coils
          final tokens = _multiValsCtrl.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
          final bools = tokens.map((t) => t == '1' || t.toLowerCase() == 'true' || t.toLowerCase() == 'on').toList();
          if (bools.isEmpty) throw Exception('Enter boolean values (e.g. 1, 0, 1)');
          await widget.client.writeMultipleCoils(unitId: unitId, startAddress: addr, values: bools);
          sw.stop();
          resultStr = "[FC15 Write Multiple Coils OK]\n";
          resultStr += "Unit: $unitId, Addr: $addr, Qty: ${bools.length}\n";
          resultStr += "Values: ${bools.map((b) => b ? 1 : 0).join(', ')}";
          break;

        case 16: // FC 16: Write Multiple Registers
          final tokens = _multiValsCtrl.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
          final vals = tokens.map((t) => _parseNumber(t) & 0xFFFF).toList();
          if (vals.isEmpty) throw Exception('Enter register values (e.g. 100, 200, 0x1A)');
          await widget.client.writeMultipleRegisters(unitId: unitId, startAddress: addr, values: vals);
          sw.stop();
          resultStr = "[FC16 Write Multiple Registers OK]\n";
          resultStr += "Unit: $unitId, Addr: $addr, Qty: ${vals.length}\n";
          resultStr += "Values: ${vals.join(', ')}";
          break;

        case 22: // FC 22: Mask Write Register
          final andMask = _parseNumber(_andMaskCtrl.text, 0xFFFF);
          final orMask = _parseNumber(_orMaskCtrl.text, 0x0000);
          await widget.client.maskWriteRegister(
            unitId: unitId,
            address: addr,
            andMask: andMask,
            orMask: orMask,
          );

          sw.stop();
          resultStr = "[FC22 Mask Write Register OK]\n";
          resultStr += "Unit: $unitId, Addr: $addr\n";
          resultStr += "AND: 0x${andMask.toRadixString(16).padLeft(4, '0').toUpperCase()}\n";
          resultStr += "OR: 0x${orMask.toRadixString(16).padLeft(4, '0').toUpperCase()}";
          break;

        case 17: // FC 17: Report Slave ID
          final pdu = await widget.client.sendPdu(
            unitId: unitId,
            pdu: Uint8List.fromList([ModbusFunctionCode.reportSlaveId.code]),
          );
          sw.stop();
          final bytesStr = pdu.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          resultStr = "[FC17 Report Slave ID OK]\n";
          resultStr += "Unit: $unitId\n";
          resultStr += "PDU Hex: $bytesStr";
          break;

        default:
          throw Exception('Unknown FC: $_selectedFc');
      }

      setState(() {
        _executionResult = resultStr;
        _isResultError = false;
        _executionLatencyMs = sw.elapsedMilliseconds;
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _executionResult = "Error: $e";
        _isResultError = true;
        _executionLatencyMs = sw.elapsedMilliseconds;
      });
    } finally {
      setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select Function Code Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppI18n.instance.t('funcCode'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _fcChoice(1, AppI18n.instance.t('readCoils')),
                      _fcChoice(2, AppI18n.instance.t('readDiscreteInputs')),
                      _fcChoice(3, AppI18n.instance.t('readHoldingRegisters')),
                      _fcChoice(4, AppI18n.instance.t('readInputRegisters')),
                      _fcChoice(5, AppI18n.instance.t('writeSingleCoil')),
                      _fcChoice(6, AppI18n.instance.t('writeSingleRegister')),
                      _fcChoice(15, AppI18n.instance.t('writeMultipleCoils')),
                      _fcChoice(16, AppI18n.instance.t('writeMultipleRegisters')),
                      _fcChoice(22, AppI18n.instance.t('maskWriteRegister')),
                      _fcChoice(17, AppI18n.instance.t('reportSlaveId')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Parameter Inputs Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppI18n.instance.t('operation'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 140,
                        child: TextField(
                          controller: _unitIdCtrl,
                          decoration: InputDecoration(labelText: AppI18n.instance.t('slaveId'), border: const OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (_selectedFc != 17)
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _addrCtrl,
                            decoration: InputDecoration(labelText: AppI18n.instance.t('startAddr'), border: const OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      if (_selectedFc <= 4)
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _qtyCtrl,
                            decoration: InputDecoration(labelText: AppI18n.instance.t('regQty'), border: const OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      if (_selectedFc == 5)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${AppI18n.instance.t('status')}: '),
                            ChoiceChip(
                              label: Text('${AppI18n.instance.t('on')} (1)'),
                              selected: _coilBoolVal,
                              onSelected: (_) => setState(() => _coilBoolVal = true),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text('${AppI18n.instance.t('off')} (0)'),
                              selected: !_coilBoolVal,
                              onSelected: (_) => setState(() => _coilBoolVal = false),
                            ),
                          ],
                        ),
                      if (_selectedFc == 6)
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _valCtrl,
                            decoration: InputDecoration(labelText: AppI18n.instance.t('currValue'), border: const OutlineInputBorder()),
                          ),
                        ),
                      if (_selectedFc == 15 || _selectedFc == 16)
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _multiValsCtrl,
                            decoration: InputDecoration(
                              labelText: AppI18n.instance.t('currValue'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      if (_selectedFc == 22) ...[
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _andMaskCtrl,
                            decoration: InputDecoration(
                              labelText: '${AppI18n.instance.t('andMask')} (0xFFFF)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _orMaskCtrl,
                            decoration: InputDecoration(
                              labelText: '${AppI18n.instance.t('orMask')} (0x0001)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        icon: _isExecuting
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send),
                        label: Text(_isExecuting ? AppI18n.instance.t('executing') : AppI18n.instance.t('executeCommand')),
                        onPressed: _isExecuting ? null : _executeCommand,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Response / Result Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text(AppI18n.instance.t('status'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_executionLatencyMs > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('${_executionLatencyMs} ms', style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isResultError ? Colors.red.shade50 : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isResultError ? Colors.red.shade300 : Colors.grey.shade800,
                      ),
                    ),
                    constraints: const BoxConstraints(minHeight: 140),
                    child: SelectableText(
                      _executionResult ?? AppI18n.instance.t('waitingInput'),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: _isResultError ? Colors.red.shade900 : Colors.greenAccent.shade400,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fcChoice(int code, String label) {
    final isSelected = _selectedFc == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFc = code),
    );
  }
}
