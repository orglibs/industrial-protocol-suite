import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../protocol/serial_port_adapter.dart';

class EditConnectionDialog extends StatefulWidget {
  final ConnectionConfig? initialConfig;

  const EditConnectionDialog({super.key, this.initialConfig});

  @override
  State<EditConnectionDialog> createState() => _EditConnectionDialogState();
}

class _EditConnectionDialogState extends State<EditConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late TextEditingController _serialPortController;

  late ModbusTransportMode _mode;
  int _baudRate = 9600;
  int _dataBits = 8;
  int _parity = 0; // 0: None, 1: Odd, 2: Even
  int _stopBits = 1;

  List<String> _availableSerialPorts = [];

  @override
  void initState() {
    super.initState();
    final c = widget.initialConfig;
    _nameController = TextEditingController(text: c?.name ?? '新连接 (Connection)');
    _ipController = TextEditingController(text: c?.ip ?? '0.0.0.0');
    _portController = TextEditingController(text: (c?.port ?? 502).toString());
    _serialPortController = TextEditingController(text: c?.serialPortName ?? '/dev/ttyUSB0');

    _mode = c?.mode ?? ModbusTransportMode.tcp;
    if (c != null) {
      _baudRate = c.baudRate;
      _dataBits = c.dataBits;
      _parity = c.parity;
      _stopBits = c.stopBits;
    }

    _refreshSerialPorts();
  }

  void _refreshSerialPorts() {
    try {
      final ports = SerialPortAdapter.getAvailablePorts();
      setState(() {
        _availableSerialPorts = ports;
        if (ports.isNotEmpty && _serialPortController.text.isEmpty) {
          _serialPortController.text = ports.first;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _serialPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSerial = _mode == ModbusTransportMode.serialRtu;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSerial ? Icons.settings_ethernet : Icons.wifi_tethering,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(widget.initialConfig == null ? '新建连接服务端' : '编辑连接参数'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '连接别名 (Connection Alias)',
                    hintText: '如: Modbus TCP 默认从站服务',
                    prefixIcon: Icon(Icons.label_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '连接别名不能为空' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ModbusTransportMode>(
                  value: _mode,
                  decoration: const InputDecoration(
                    labelText: '通信模式 (Connection Mode)',
                    prefixIcon: Icon(Icons.swap_horiz),
                    border: OutlineInputBorder(),
                  ),
                  items: ModbusTransportMode.values.map((m) {
                    return DropdownMenuItem(value: m, child: Text(m.label));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _mode = val);
                  },
                ),
                const SizedBox(height: 16),

                if (!isSerial) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: '监听 IP (0.0.0.0 为所有网卡)',
                            prefixIcon: Icon(Icons.computer),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'IP不能为空' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '端口 (Port)',
                            prefixIcon: Icon(Icons.tag),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final p = int.tryParse(v ?? '');
                            if (p == null || p < 1 || p > 65535) return '1-65535';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _serialPortController,
                          decoration: InputDecoration(
                            labelText: '串口设备 (Serial Port)',
                            hintText: '/dev/ttyUSB0 或 COM1',
                            prefixIcon: const Icon(Icons.usb),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: '扫描可用串口',
                              onPressed: _refreshSerialPorts,
                            ),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? '串口名称不能为空' : null,
                        ),
                      ),
                    ],
                  ),
                  if (_availableSerialPorts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _availableSerialPorts.map((p) {
                        return ActionChip(
                          avatar: const Icon(Icons.cable, size: 14),
                          label: Text(p, style: const TextStyle(fontSize: 12)),
                          onPressed: () => setState(() => _serialPortController.text = p),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _baudRate,
                          decoration: const InputDecoration(
                            labelText: '波特率 (BaudRate)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200]
                              .map((b) => DropdownMenuItem(value: b, child: Text('$b bps')))
                              .toList(),
                          onChanged: (v) => setState(() => _baudRate = v ?? 9600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _dataBits,
                          decoration: const InputDecoration(
                            labelText: '数据位 (Data Bits)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [7, 8]
                              .map((d) => DropdownMenuItem(value: d, child: Text('$d 位')))
                              .toList(),
                          onChanged: (v) => setState(() => _dataBits = v ?? 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _parity,
                          decoration: const InputDecoration(
                            labelText: '校验位 (Parity)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('无校验 (None)')),
                            DropdownMenuItem(value: 1, child: Text('奇校验 (Odd)')),
                            DropdownMenuItem(value: 2, child: Text('偶校验 (Even)')),
                          ],
                          onChanged: (v) => setState(() => _parity = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _stopBits,
                          decoration: const InputDecoration(
                            labelText: '停止位 (Stop Bits)',
                            border: OutlineInputBorder(),
                          ),
                          items: const [1, 2]
                              .map((s) => DropdownMenuItem(value: s, child: Text('$s 位')))
                              .toList(),
                          onChanged: (v) => setState(() => _stopBits = v ?? 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('保存'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final port = int.tryParse(_portController.text.trim()) ?? 502;
              final config = widget.initialConfig ?? ConnectionConfig();
              config.name = _nameController.text.trim();
              config.mode = _mode;
              config.ip = _ipController.text.trim();
              config.port = port;
              config.serialPortName = _serialPortController.text.trim();
              config.baudRate = _baudRate;
              config.dataBits = _dataBits;
              config.parity = _parity;
              config.stopBits = _stopBits;

              if (config.slaves.isEmpty) {
                config.slaves.add(ConnectionConfig.createDefaultSlave(1));
              }

              Navigator.of(context).pop(config);
            }
          },
        ),
      ],
    );
  }
}
