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
          resultStr = '【FC 01 读取线圈成功】\n从机ID: $unitId, 起始地址: $addr, 读取点数: $qty\n响应线圈状态: \n$bitLines';
          break;

        case 2: // FC 02: Read Discrete Inputs
          final bits = await widget.client.readDiscreteInputs(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final discLines = bits.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value ? "1" : "0"}').join('\n');
          resultStr = '【FC 02 读取离散输入成功】\n从机ID: $unitId, 起始地址: $addr, 读取点数: $qty\n响应输入状态: \n$discLines';
          break;

        case 3: // FC 03: Read Holding Registers
          final words = await widget.client.readHoldingRegisters(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final holdLines = words.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value} (0x${e.value.toRadixString(16).padLeft(4, "0").toUpperCase()})').join('\n');
          resultStr = '【FC 03 读取保持寄存器成功】\n从机ID: $unitId, 起始地址: $addr, 数量: $qty\n寄存器值: \n$holdLines';
          break;

        case 4: // FC 04: Read Input Registers
          final words = await widget.client.readInputRegisters(unitId: unitId, startAddress: addr, quantity: qty);
          sw.stop();
          final inputLines = words.asMap().entries.map((e) => '  [${addr + e.key}]: ${e.value} (0x${e.value.toRadixString(16).padLeft(4, "0").toUpperCase()})').join('\n');
          resultStr = '【FC 04 读取输入寄存器成功】\n从机ID: $unitId, 起始地址: $addr, 数量: $qty\n寄存器值: \n$inputLines';
          break;


        case 5: // FC 05: Write Single Coil
          await widget.client.writeSingleCoil(unitId: unitId, address: addr, value: _coilBoolVal);
          sw.stop();
          resultStr = '【FC 05 写单个线圈成功】\n'
              '从机ID: $unitId, 地址: $addr, 目标状态: ${_coilBoolVal ? "ON (0xFF00)" : "OFF (0x0000)"}\n'
              '从站已正确应答确认！';
          break;

        case 6: // FC 06: Write Single Register
          final val = _parseNumber(_valCtrl.text);
          await widget.client.writeSingleRegister(unitId: unitId, address: addr, value: val & 0xFFFF);
          sw.stop();
          resultStr = '【FC 06 写单个保持寄存器成功】\n'
              '从机ID: $unitId, 地址: $addr, 写入值: $val (0x${(val & 0xFFFF).toRadixString(16).padLeft(4, "0").toUpperCase()})\n'
              '从站已确认写入！';
          break;

        case 15: // FC 15: Write Multiple Coils
          final tokens = _multiValsCtrl.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
          final bools = tokens.map((t) => t == '1' || t.toLowerCase() == 'true' || t.toLowerCase() == 'on').toList();
          if (bools.isEmpty) throw Exception('请输入要写入的布尔值 (如 1, 0, 1, 1)');
          await widget.client.writeMultipleCoils(unitId: unitId, startAddress: addr, values: bools);
          sw.stop();
          resultStr = '【FC 15 写多个线圈成功】\n'
              '从机ID: $unitId, 起始地址: $addr, 写入数量: ${bools.length}\n'
              '状态列表: ${bools.map((b) => b ? 1 : 0).join(", ")}';
          break;

        case 16: // FC 16: Write Multiple Registers
          final tokens = _multiValsCtrl.text.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).toList();
          final vals = tokens.map((t) => _parseNumber(t) & 0xFFFF).toList();
          if (vals.isEmpty) throw Exception('请输入要写入的寄存器值 (如 100, 200, 0x1A)');
          await widget.client.writeMultipleRegisters(unitId: unitId, startAddress: addr, values: vals);
          sw.stop();
          resultStr = '【FC 16 批量写多个保持寄存器成功】\n'
              '从机ID: $unitId, 起始地址: $addr, 写入数量: ${vals.length}\n'
              '数值列表: ${vals.join(", ")}';
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
          resultStr = '【FC 22 掩码写入保持寄存器成功】\n'
              '从机ID: $unitId, 地址: $addr\n'
              'AND 掩码: 0x${andMask.toRadixString(16).padLeft(4, "0").toUpperCase()}\n'
              'OR 掩码: 0x${orMask.toRadixString(16).padLeft(4, "0").toUpperCase()}\n'
              '从站确认已按掩码执行运算: [新值 = (当前值 AND AndMask) OR (OrMask AND (NOT AndMask))]';
          break;

        case 17: // FC 17: Report Slave ID
          final pdu = await widget.client.sendPdu(
            unitId: unitId,
            pdu: Uint8List.fromList([ModbusFunctionCode.reportSlaveId.code]),
          );
          sw.stop();
          final bytesStr = pdu.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
          resultStr = '【FC 17 读取从站标识成功】\n'
              '从机ID: $unitId\n'
              'PDU响应十六进制: $bytesStr';
          break;

        default:
          throw Exception('未知功能码: $_selectedFc');
      }

      setState(() {
        _executionResult = resultStr;
        _isResultError = false;
        _executionLatencyMs = sw.elapsedMilliseconds;
      });
    } catch (e) {
      sw.stop();
      setState(() {
        _executionResult = '执行错误 (异常应答 / 通信故障):\n$e';
        _isResultError = true;
        _executionLatencyMs = sw.elapsedMilliseconds;
      });
    } finally {
      setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const Text('选择 Modbus 功能码 (Function Code)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _fcChoice(1, '01: 读线圈 (FC01)'),
                      _fcChoice(2, '02: 读离散输入 (FC02)'),
                      _fcChoice(3, '03: 读保持寄存器 (FC03)'),
                      _fcChoice(4, '04: 读输入寄存器 (FC04)'),
                      _fcChoice(5, '05: 写单个线圈 (FC05)'),
                      _fcChoice(6, '06: 写单个寄存器 (FC06)'),
                      _fcChoice(15, '15: 写多个线圈 (FC15)'),
                      _fcChoice(16, '16: 写多个寄存器 (FC16)'),
                      _fcChoice(22, '22: 掩码写寄存器 (FC22)'),
                      _fcChoice(17, '17: 读从站标识 (FC17)'),
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
                  const Text('指令目标与执行参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                          decoration: const InputDecoration(labelText: '从站 ID (Unit ID)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (_selectedFc != 17)
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _addrCtrl,
                            decoration: const InputDecoration(labelText: '起始地址 (Address)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      if (_selectedFc <= 4)
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _qtyCtrl,
                            decoration: const InputDecoration(labelText: '读取点数 (Quantity)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      if (_selectedFc == 5)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('线圈状态: '),
                            ChoiceChip(
                              label: const Text('ON (置1)'),
                              selected: _coilBoolVal,
                              onSelected: (_) => setState(() => _coilBoolVal = true),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('OFF (置0)'),
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
                            decoration: const InputDecoration(labelText: '写入值 (Value - 支持 0xHex)', border: OutlineInputBorder()),
                          ),
                        ),
                      if (_selectedFc == 15 || _selectedFc == 16)
                        SizedBox(
                          width: 320,
                          child: TextField(
                            controller: _multiValsCtrl,
                            decoration: InputDecoration(
                              labelText: _selectedFc == 15 ? '布尔值列表 (如 1, 0, 1)' : '寄存器值列表 (如 100, 200, 0x1A)',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      if (_selectedFc == 22) ...[
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _andMaskCtrl,
                            decoration: const InputDecoration(labelText: 'AND 掩码 (0xFFFF)', border: OutlineInputBorder()),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _orMaskCtrl,
                            decoration: const InputDecoration(labelText: 'OR 掩码 (0x0001)', border: OutlineInputBorder()),
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
                        label: const Text('立即执行指令'),
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
                      const Text('指令响应结果 (Response Inspector)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_executionLatencyMs > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('耗时: ${_executionLatencyMs}ms', style: const TextStyle(fontSize: 12)),
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
                      _executionResult ?? '等待下发指令...',
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
