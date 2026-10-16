import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../protocol/modbus_crc.dart';
import '../../protocol/modbus_data_types.dart';
import '../../protocol/serial_port_adapter.dart';

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> {
  int _selectedSubTool = 0; // 0: Number<->Bytes, 1: CRC/LRC, 2: Encoding/Decoding, 3: Serial Detect

  // Tool 1: Number <-> Bytes
  String _numInput = '123.456';
  RegisterDataFormat _numFormat = RegisterDataFormat.float32;
  ModbusByteOrder _numByteOrder = ModbusByteOrder.abcd;
  String _bytesOutputHex = '';
  String _bytesInputHex = '42 F6 E9 79';
  String _numberOutput = '';

  // Tool 2: Redundancy Check
  final TextEditingController _crcInputController = TextEditingController(text: '01 03 00 00 00 0A');
  String _crc16Result = '';
  String _lrcResult = '';
  String _sum8Result = '';

  // Tool 3: Character Encoding
  final TextEditingController _textInputController = TextEditingController(text: 'MODBUS SLAVE');
  final TextEditingController _hexInputController = TextEditingController(text: '4D 4F 44 42 55 53 20 53 4C 41 56 45');

  // Tool 4: Serial Port Detector
  List<String> _detectedPorts = [];
  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _calcNumberToBytes();
    _calcBytesToNumber();
    _calcCrc();
    _detectSerialPorts();
  }

  @override
  void dispose() {
    _crcInputController.dispose();
    _textInputController.dispose();
    _hexInputController.dispose();
    super.dispose();
  }

  void _calcNumberToBytes() {
    try {
      final words = ModbusDataConverter.parseInputTextToWords(_numInput, _numFormat, _numByteOrder);
      if (words != null && words.isNotEmpty) {
        final bytes = ModbusDataConverter.registersToBytes(words);
        setState(() {
          _bytesOutputHex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        });
        return;
      }
    } catch (_) {}
    setState(() => _bytesOutputHex = '转换失败: 输入无效');
  }

  void _calcBytesToNumber() {
    try {
      final clean = _bytesInputHex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      final bytes = <int>[];
      for (int i = 0; i < clean.length - 1; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      final uint8 = Uint8List.fromList(bytes);
      final val = ModbusDataConverter.parseValue(uint8, _numFormat, _numByteOrder);
      setState(() => _numberOutput = val.toString());
    } catch (e) {
      setState(() => _numberOutput = '解析错误: $e');
    }
  }

  void _calcCrc() {
    try {
      final clean = _crcInputController.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
      final bytes = <int>[];
      for (int i = 0; i < clean.length - 1; i += 2) {
        bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      if (bytes.isEmpty) {
        setState(() {
          _crc16Result = '';
          _lrcResult = '';
          _sum8Result = '';
        });
        return;
      }
      final uint8 = Uint8List.fromList(bytes);
      final crc = ModbusCrc.calculateCrc16(uint8);
      final lrc = ModbusCrc.calculateLrc(uint8);
      int sum8 = 0;
      for (final b in bytes) {
        sum8 = (sum8 + b) & 0xFF;
      }

      setState(() {
        final crcLo = (crc & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
        final crcHi = ((crc >> 8) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
        _crc16Result = '$crcLo $crcHi (低位在前: 0x${crc.toRadixString(16).padLeft(4, "0").toUpperCase()})';
        _lrcResult = '0x${lrc.toRadixString(16).padLeft(2, "0").toUpperCase()}';
        _sum8Result = '0x${sum8.toRadixString(16).padLeft(2, "0").toUpperCase()}';
      });
    } catch (_) {}
  }

  void _detectSerialPorts() {
    setState(() => _isDetecting = true);
    try {
      final ports = SerialPortAdapter.getAvailablePorts();
      setState(() {
        _detectedPorts = ports;
        _isDetecting = false;
      });
    } catch (_) {
      setState(() => _isDetecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          // Sub-navigation
          NavigationRail(
            selectedIndex: _selectedSubTool,
            onDestinationSelected: (idx) => setState(() => _selectedSubTool = idx),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.calculate_outlined),
                selectedIcon: Icon(Icons.calculate),
                label: Text('数值/字节转换'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified),
                label: Text('校验算法 (CRC)'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.text_fields_outlined),
                selectedIcon: Icon(Icons.text_fields),
                label: Text('字符编解码'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.usb_outlined),
                selectedIcon: Icon(Icons.usb),
                label: Text('串口探测'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Tool Content Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: IndexedStack(
                index: _selectedSubTool,
                children: [
                  _buildNumberToBytesView(theme),
                  _buildRedundancyCheckView(theme),
                  _buildEncodingDecodingView(theme),
                  _buildSerialPortDetectView(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Number <-> Bytes View
  Widget _buildNumberToBytesView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('数值 ⇋ 字节转换器 (Number <-> Bytes)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('复刻 MSE 的 FloatToBytes, DoubleToBytes, LongToBytes 转换模块，支持多种端序'),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RegisterDataFormat>(
                  value: _numFormat,
                  decoration: const InputDecoration(labelText: '目标数据类型', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: RegisterDataFormat.float32, child: Text('32位 浮点数 (Float32)')),
                    DropdownMenuItem(value: RegisterDataFormat.double64, child: Text('64位 双精度浮点 (Double64)')),
                    DropdownMenuItem(value: RegisterDataFormat.signed32, child: Text('32位 有符号整数 (Int32)')),
                    DropdownMenuItem(value: RegisterDataFormat.unsigned32, child: Text('32位 无符号整数 (UInt32)')),
                    DropdownMenuItem(value: RegisterDataFormat.signed16, child: Text('16位 有符号整数 (Int16)')),
                    DropdownMenuItem(value: RegisterDataFormat.unsigned16, child: Text('16位 无符号整数 (UInt16)')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _numFormat = v);
                      _calcNumberToBytes();
                      _calcBytesToNumber();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<ModbusByteOrder>(
                  value: _numByteOrder,
                  decoration: const InputDecoration(labelText: '字节序 / 大小端 (Byte Order)', border: OutlineInputBorder()),
                  items: ModbusByteOrder.values.map((o) {
                    return DropdownMenuItem(value: o, child: Text(o.label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _numByteOrder = v);
                      _calcNumberToBytes();
                      _calcBytesToNumber();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数值转十六进制字节 (Number -> Hex Bytes)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _numInput,
                          decoration: const InputDecoration(
                            labelText: '输入数值 (Number)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            _numInput = v;
                            _calcNumberToBytes();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            'Hex: $_bytesOutputHex',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('十六进制字节转数值 (Hex Bytes -> Number)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _bytesInputHex,
                          decoration: const InputDecoration(
                            labelText: '输入十六进制字节 (如: 42 F6 E9 79)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            _bytesInputHex = v;
                            _calcBytesToNumber();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Text(
                            '数值: $_numberOutput',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Redundancy Check View
  Widget _buildRedundancyCheckView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('校验码计算器 (Redundancy Check Calculator)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('复刻 MSE 的 RedundancyCheckWindow，计算 Modbus CRC-16、ASCII LRC 及校验和'),
          const SizedBox(height: 24),
          TextField(
            controller: _crcInputController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '输入十六进制数据流 (空格分隔)',
              hintText: '如: 01 03 00 00 00 0A',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calcCrc(),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Modbus CRC-16 (多项式 0xA001)'),
                    subtitle: Text(
                      _crc16Result.isEmpty ? '等待输入' : _crc16Result,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Modbus ASCII LRC 纵向冗余校验'),
                    subtitle: Text(
                      _lrcResult.isEmpty ? '等待输入' : _lrcResult,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.verified_outlined, color: Colors.blue),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('累加校验和 (Sum 8)'),
                    subtitle: Text(
                      _sum8Result.isEmpty ? '等待输入' : _sum8Result,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.tag, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Encoding / Decoding View
  Widget _buildEncodingDecodingView(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('字符编解码器 (Character Encoding / Decoding)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('复刻 MSE 的 CharacterEncodingDecodingWindow，在 ASCII/UTF-8 与十六进制之间互转'),
          const SizedBox(height: 24),
          TextField(
            controller: _textInputController,
            decoration: const InputDecoration(
              labelText: '字符串文本 (Text)',
              border: OutlineInputBorder(),
            ),
            onChanged: (text) {
              final bytes = utf8.encode(text);
              _hexInputController.text = bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hexInputController,
            decoration: const InputDecoration(
              labelText: '十六进制编码 (Hex String)',
              border: OutlineInputBorder(),
            ),
            onChanged: (hex) {
              try {
                final clean = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
                final bytes = <int>[];
                for (int i = 0; i < clean.length - 1; i += 2) {
                  bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
                }
                _textInputController.text = utf8.decode(bytes, allowMalformed: true);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  // 4. Serial Port Detect View
  Widget _buildSerialPortDetectView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('串口探测与状态检测 (Serial Port Detection)', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text('复刻 MSE 的 SerialPortOccupancyDetectionWindow，检测主机可用物理串口与虚拟串口设备'),
              ],
            ),
            FilledButton.icon(
              icon: _isDetecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh),
              label: const Text('重新扫描'),
              onPressed: _isDetecting ? null : _detectSerialPorts,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _detectedPorts.isEmpty
              ? const Center(
                  child: Text('未扫描到可用串口设备 (若使用 USB 转串口，请插入并检查驱动或 sudo chmod 666 /dev/ttyUSB0)'),
                )
              : ListView.builder(
                  itemCount: _detectedPorts.length,
                  itemBuilder: (context, idx) {
                    final port = _detectedPorts[idx];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.usb, color: Colors.blue),
                        title: Text(port, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        subtitle: Text(port.contains('USB') ? 'USB 转串口设备' : '系统标准 TTY / 虚拟终端'),
                        trailing: const Chip(
                          label: Text('就绪可用', style: TextStyle(color: Colors.green)),
                          backgroundColor: Color(0x224CAF50),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
