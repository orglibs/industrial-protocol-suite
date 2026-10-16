import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../protocol/serial_port_adapter.dart';

class EditConnectionDialog extends StatefulWidget {
  final ConnectionConfig? connection;
  final int defaultIndex;

  const EditConnectionDialog({
    super.key,
    this.connection,
    this.defaultIndex = 1,
  });

  static Future<ConnectionConfig?> show(
    BuildContext context, {
    ConnectionConfig? connection,
    int defaultIndex = 1,
  }) {
    return showDialog<ConnectionConfig>(
      context: context,
      builder: (_) => EditConnectionDialog(
        connection: connection,
        defaultIndex: defaultIndex,
      ),
    );
  }

  @override
  State<EditConnectionDialog> createState() => _EditConnectionDialogState();
}

class _EditConnectionDialogState extends State<EditConnectionDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _ipCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _timeoutCtrl;

  late ModbusTransportMode _mode;
  String? _serialPortName;
  late int _baudRate;
  late int _dataBits;
  late int _parity;
  late int _stopBits;
  bool _presetDefaultSlave = true;

  List<String> _availablePorts = [];
  static const List<int> _baudRates = [1200, 2400, 4800, 9600, 19200, 38400, 57600, 115200];
  static const List<int> _dataBitsList = [8, 7];
  static const Map<int, String> _parityLabels = {0: '无校验 (None)', 1: '奇校验 (Odd)', 2: '偶校验 (Even)'};
  static const List<int> _stopBitsList = [1, 2];

  @override
  void initState() {
    super.initState();
    final c = widget.connection;
    _nameCtrl = TextEditingController(text: c?.name ?? 'Connection ${widget.defaultIndex}');
    _ipCtrl = TextEditingController(text: c?.ip ?? '127.0.0.1');
    _portCtrl = TextEditingController(text: (c?.port ?? 502).toString());
    _timeoutCtrl = TextEditingController(text: (c?.timeoutMs ?? 1500).toString());

    _mode = c?.mode ?? ModbusTransportMode.tcp;
    _serialPortName = c?.serialPortName;
    _baudRate = c?.baudRate ?? 9600;
    _dataBits = c?.dataBits ?? 8;
    _parity = c?.parity ?? 0;
    _stopBits = c?.stopBits ?? 1;

    _scanPorts();
  }

  void _scanPorts() {
    final ports = SerialPortAdapter.getAvailablePorts();
    setState(() {
      _availablePorts = ports;
      if (_serialPortName != null && !_availablePorts.contains(_serialPortName)) {
        _availablePorts.add(_serialPortName!);
      }
      if ((_serialPortName == null || _serialPortName!.isEmpty) && _availablePorts.isNotEmpty) {
        _serialPortName = _availablePorts.first;
      }
    });
  }

  void _showManualPortDialog() {
    final textCtrl = TextEditingController(text: _serialPortName ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动指定串口设备节点'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请输入物理串口设备节点路径 (如 /dev/ttyUSB0 或 COM1):', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '串口设备路径',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.usb),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final val = textCtrl.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  _serialPortName = val;
                  if (!_availablePorts.contains(val)) {
                    _availablePorts.add(val);
                  }
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim().isEmpty ? 'Connection ${widget.defaultIndex}' : _nameCtrl.text.trim();
    final ip = _ipCtrl.text.trim().isEmpty ? '127.0.0.1' : _ipCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 502;
    final timeout = int.tryParse(_timeoutCtrl.text.trim()) ?? 1500;

    if (widget.connection != null) {
      final c = widget.connection!;
      c.name = name;
      c.mode = _mode;
      c.ip = ip;
      c.port = port;
      c.serialPortName = _serialPortName ?? (_availablePorts.isNotEmpty ? _availablePorts.first : '/dev/ttyUSB0');
      c.baudRate = _baudRate;
      c.dataBits = _dataBits;
      c.parity = _parity;
      c.stopBits = _stopBits;
      c.timeoutMs = timeout;
      c.messageFrameFormat = (_mode == ModbusTransportMode.serialRtu || _mode == ModbusTransportMode.rtuOverTcp) ? 1 : 0;
      Navigator.of(context).pop(c);
    } else {
      final newConn = ConnectionConfig(
        name: name,
        mode: _mode,
        ip: ip,
        port: port,
        serialPortName: _serialPortName ?? (_availablePorts.isNotEmpty ? _availablePorts.first : '/dev/ttyUSB0'),
        baudRate: _baudRate,
        dataBits: _dataBits,
        parity: _parity,
        stopBits: _stopBits,
        timeoutMs: timeout,
        messageFrameFormat: (_mode == ModbusTransportMode.serialRtu || _mode == ModbusTransportMode.rtuOverTcp) ? 1 : 0,
        slaves: _presetDefaultSlave ? [ConnectionConfig.createDefaultSlave()] : [],
      );
      Navigator.of(context).pop(newConn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.connection != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(isEdit ? Icons.edit : Icons.add_link, color: Colors.indigo),
          const SizedBox(width: 8),
          Text(isEdit ? '编辑连接配置' : '新建通信连接 (Create Connection)'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '连接别名 (Connection Alias)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<ModbusTransportMode>(
                key: ValueKey(_mode),
                isExpanded: true,
                initialValue: _mode,
                decoration: const InputDecoration(
                  labelText: '工作模式 (Transport Mode)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
                items: ModbusTransportMode.values.map((m) {
                  return DropdownMenuItem(value: m, child: Text(m.label));
                }).toList(),
                onChanged: (m) {
                  if (m != null) setState(() => _mode = m);
                },
              ),
              const SizedBox(height: 14),

              // Serial RTU options
              if (_mode == ModbusTransportMode.serialRtu) ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_serialPortName),
                        isExpanded: true,
                        initialValue: _availablePorts.contains(_serialPortName)
                            ? _serialPortName
                            : (_availablePorts.isNotEmpty ? _availablePorts.first : null),
                        decoration: const InputDecoration(
                          labelText: '串口设备 (Port)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.usb),
                        ),
                        items: _availablePorts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (p) => setState(() => _serialPortName = p),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note),
                      tooltip: '手动输入串口路径',
                      onPressed: _showManualPortDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: '重新扫描串口',
                      onPressed: _scanPorts,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_baudRate),
                        isExpanded: true,
                        initialValue: _baudRate,
                        decoration: const InputDecoration(labelText: '波特率', border: OutlineInputBorder()),
                        items: _baudRates.map((b) => DropdownMenuItem(value: b, child: Text(b.toString()))).toList(),
                        onChanged: (v) => setState(() => _baudRate = v ?? 9600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_dataBits),
                        isExpanded: true,
                        initialValue: _dataBits,
                        decoration: const InputDecoration(labelText: '数据位', border: OutlineInputBorder()),
                        items: _dataBitsList.map((d) => DropdownMenuItem(value: d, child: Text('$d 位'))).toList(),
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
                        key: ValueKey(_parity),
                        isExpanded: true,
                        initialValue: _parity,
                        decoration: const InputDecoration(labelText: '校验位', border: OutlineInputBorder()),
                        items: _parityLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                        onChanged: (v) => setState(() => _parity = v ?? 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_stopBits),
                        isExpanded: true,
                        initialValue: _stopBits,
                        decoration: const InputDecoration(labelText: '停止位', border: OutlineInputBorder()),
                        items: _stopBitsList.map((s) => DropdownMenuItem(value: s, child: Text('$s 位'))).toList(),
                        onChanged: (v) => setState(() => _stopBits = v ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // TCP options
              if (_mode == ModbusTransportMode.tcp || _mode == ModbusTransportMode.rtuOverTcp) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _ipCtrl,
                        decoration: const InputDecoration(
                          labelText: '目标 IP 地址 / 主机名',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.dns),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _portCtrl,
                        decoration: const InputDecoration(
                          labelText: '端口 (Port)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              if (_mode == ModbusTransportMode.virtual) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.memory, color: Colors.indigo),
                      SizedBox(width: 8),
                      Expanded(child: Text('本地虚拟仿真连接：无需外部硬件设备，连接后即可读写仿真电表与开关数据。', style: TextStyle(fontSize: 12, color: Colors.indigo))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _timeoutCtrl,
                decoration: const InputDecoration(
                  labelText: '超时时间 (Timeout ms)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
              ),

              if (!isEdit) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('预置默认从站和寄存器点表 (推荐)', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('自动包含示例电力模拟量与遥信点号任务', style: TextStyle(fontSize: 12)),
                  value: _presetDefaultSlave,
                  onChanged: (v) => setState(() => _presetDefaultSlave = v ?? true),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          onPressed: _save,
          child: Text(isEdit ? '保存更改' : '创建连接'),
        ),
      ],
    );
  }
}
