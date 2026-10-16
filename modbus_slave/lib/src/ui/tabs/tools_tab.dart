import '../../i18n/app_i18n.dart';
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
    setState(() => _bytesOutputHex = AppI18n.instance.t('convertFailed'));
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
      setState(() => _numberOutput = '${AppI18n.instance.t('parseError')}: $e');
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
        _crc16Result = '$crcLo $crcHi (0x${crc.toRadixString(16).padLeft(4, "0").toUpperCase()})';
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
                label: Text(AppI18n.instance.t('numByteConvert')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_outlined),
                selectedIcon: Icon(Icons.verified),
                label: Text(AppI18n.instance.t('checkAlgo')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.text_fields_outlined),
                selectedIcon: Icon(Icons.text_fields),
                label: Text(AppI18n.instance.t('charCodec')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.usb_outlined),
                selectedIcon: Icon(Icons.usb),
                label: Text(AppI18n.instance.t('serialDetect')),
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
          Text(AppI18n.instance.t('numByteConvert'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(AppI18n.instance.t('dataFormat')),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RegisterDataFormat>(
                  value: _numFormat,
                  decoration: InputDecoration(labelText: AppI18n.instance.t('dataFormat'), border: const OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: RegisterDataFormat.float32, child: Text('Float32 (32-bit)')),
                    DropdownMenuItem(value: RegisterDataFormat.double64, child: Text('Double64 (64-bit)')),
                    DropdownMenuItem(value: RegisterDataFormat.signed32, child: Text('Int32 (32-bit)')),
                    DropdownMenuItem(value: RegisterDataFormat.unsigned32, child: Text('UInt32 (32-bit)')),
                    DropdownMenuItem(value: RegisterDataFormat.signed16, child: Text('Int16 (16-bit)')),
                    DropdownMenuItem(value: RegisterDataFormat.unsigned16, child: Text('UInt16 (16-bit)')),
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
                  decoration: InputDecoration(labelText: AppI18n.instance.t('byteOrder'), border: const OutlineInputBorder()),
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
                  Text(AppI18n.instance.t('numToHex'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _numInput,
                          decoration: const InputDecoration(
                            labelText: AppI18n.instance.t('inputNum'),
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
                  Text(AppI18n.instance.t('hexToNum'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _bytesInputHex,
                          decoration: const InputDecoration(
                            labelText: AppI18n.instance.t('inputHex'),
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
                            '${AppI18n.instance.t('currValue')}: $_numberOutput',
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
          Text(AppI18n.instance.t('checkAlgo'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(AppI18n.instance.t('checkAlgo')),
          const SizedBox(height: 24),
          TextField(
            controller: _crcInputController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: AppI18n.instance.t('inputHex'),
              hintText: '01 03 00 00 00 0A',
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
                    title: const Text('Modbus CRC-16 (0xA001)'),
                    subtitle: Text(
                      _crc16Result.isEmpty ? AppI18n.instance.t('waitingInput') : _crc16Result,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Modbus ASCII LRC'),
                    subtitle: Text(
                      _lrcResult.isEmpty ? AppI18n.instance.t('waitingInput') : _lrcResult,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                    ),
                    trailing: const Icon(Icons.verified_outlined, color: Colors.blue),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Sum 8 (Checksum)'),
                    subtitle: Text(
                      _sum8Result.isEmpty ? AppI18n.instance.t('waitingInput') : _sum8Result,
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
          Text(AppI18n.instance.t('charCodec'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(AppI18n.instance.t('charCodec')),
          const SizedBox(height: 24),
          TextField(
            controller: _textInputController,
            decoration: const InputDecoration(
              labelText: 'Text (ASCII / UTF-8)',
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
              labelText: 'Hex Bytes',
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
                Text(AppI18n.instance.t('serialDetect'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(AppI18n.instance.t('serialDetect')),
              ],
            ),
            FilledButton.icon(
              icon: _isDetecting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.refresh),
              label: Text(AppI18n.instance.t('rescan')),
              onPressed: _isDetecting ? null : _detectSerialPorts,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: _detectedPorts.isEmpty
              ? const Center(
                  child: Text(AppI18n.instance.t('noSerialFound')),
                )
              : ListView.builder(
                  itemCount: _detectedPorts.length,
                  itemBuilder: (context, idx) {
                    final port = _detectedPorts[idx];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.usb, color: Colors.blue),
                        title: Text(port, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        subtitle: Text(port.contains('USB') ? 'USB Serial Port' : 'System TTY / Virtual Terminal'),
                        trailing: const Chip(
                          label: Text(AppI18n.instance.t('serialReady'), style: const TextStyle(color: Colors.green)),
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
