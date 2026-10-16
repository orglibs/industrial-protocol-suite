import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../protocol/modbus_client.dart';
import '../../protocol/modbus_crc.dart';
import '../../protocol/modbus_data_types.dart';
import '../../services/address_scanner.dart';
import '../../services/stress_test_service.dart';

class ToolsTab extends StatefulWidget {
  final ModbusClient client;

  const ToolsTab({super.key, required this.client});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // CRC Calculator state
  final TextEditingController _crcHexCtrl = TextEditingController(text: '01 03 00 00 00 0A');
  String _calculatedCrc = '';
  String _calculatedLrc = '';
  String _fullAduHex = '';

  // Data Converter state
  final TextEditingController _floatInputCtrl = TextEditingController(text: '220.5');
  final TextEditingController _int32InputCtrl = TextEditingController(text: '123456');

  // Scanner state
  late AddressScannerService _scannerService;
  final List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  final TextEditingController _scanFromIdCtrl = TextEditingController(text: '1');
  final TextEditingController _scanToIdCtrl = TextEditingController(text: '16');

  // Stress test state
  late StressTestService _stressService;
  StressTestReport? _stressReport;
  bool _isStressRunning = false;
  final TextEditingController _stressCountCtrl = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scannerService = AddressScannerService(widget.client);
    _stressService = StressTestService(widget.client);
    _calculateCrc();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _crcHexCtrl.dispose();
    _floatInputCtrl.dispose();
    _int32InputCtrl.dispose();
    _scanFromIdCtrl.dispose();
    _scanToIdCtrl.dispose();
    _stressCountCtrl.dispose();
    super.dispose();
  }

  // --- CRC Calculator Logic ---
  void _calculateCrc() {
    final hex = _crcHexCtrl.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.length % 2 != 0 || hex.isEmpty) {
      setState(() {
        _calculatedCrc = '请输入成对的十六进制字节 (如 01 03 00 00 00 0A)';
        _calculatedLrc = '';
        _fullAduHex = '';
      });
      return;
    }

    final bytes = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }

    final crcVal = ModbusCrc.calculateCrc16(bytes);
    final lrcVal = ModbusCrc.calculateLrc(bytes);

    final crcLow = crcVal & 0xFF;
    final crcHigh = (crcVal >> 8) & 0xFF;
    final crcHexStr = '0x${crcVal.toRadixString(16).padLeft(4, "0").toUpperCase()} (低字节: 0x${crcLow.toRadixString(16).padLeft(2, "0").toUpperCase()}, 高字节: 0x${crcHigh.toRadixString(16).padLeft(2, "0").toUpperCase()})';
    final lrcHexStr = '0x${lrcVal.toRadixString(16).padLeft(2, "0").toUpperCase()}';

    // RTU ADU = Payload + CRC Low + CRC High
    final fullBytes = [...bytes, crcLow, crcHigh];
    final fullHex = fullBytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

    setState(() {
      _calculatedCrc = crcHexStr;
      _calculatedLrc = lrcHexStr;
      _fullAduHex = fullHex;
    });
  }

  // --- Address Scanner Logic ---
  void _startSlaveScan() async {
    final fromId = int.tryParse(_scanFromIdCtrl.text.trim()) ?? 1;
    final toId = int.tryParse(_scanToIdCtrl.text.trim()) ?? 16;

    setState(() {
      _scanResults.clear();
      _isScanning = true;
    });

    await for (final res in _scannerService.scanSlaveIds(fromId: fromId, toId: toId)) {
      if (!mounted) break;
      setState(() {
        _scanResults.add(res);
      });
    }

    if (mounted) setState(() => _isScanning = false);
  }

  // --- Stress Test Logic ---
  void _startStressTest() async {
    final count = int.tryParse(_stressCountCtrl.text.trim()) ?? 100;
    setState(() => _isStressRunning = true);

    await for (final report in _stressService.runBenchmark(totalCount: count)) {
      if (!mounted) break;
      setState(() {
        _stressReport = report;
      });
    }

    if (mounted) setState(() => _isStressRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          indicatorColor: theme.colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.calculate), text: 'CRC16 / LRC 校验计算器'),
            Tab(icon: Icon(Icons.swap_horiz), text: '数据格式与字节序转换器'),
            Tab(icon: Icon(Icons.radar), text: '从站与点号自动扫描器'),
            Tab(icon: Icon(Icons.speed), text: '高频压力与稳定性基准测试'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCrcView(),
              _buildConverterView(),
              _buildScannerView(),
              _buildStressView(),
            ],
          ),
        ),
      ],
    );
  }

  // 1. CRC Calculator View
  Widget _buildCrcView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Modbus RTU CRC-16 与 ASCII LRC 快速校验计算器', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _crcHexCtrl,
            decoration: const InputDecoration(
              labelText: '输入十六进制数据流 (以空格或连续hex输入)',
              hintText: '如 01 03 00 00 00 0A',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.code),
            ),
            onChanged: (_) => _calculateCrc(),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Modbus CRC-16 (多项式 0xA001):', _calculatedCrc),
                  const Divider(height: 20),
                  _infoRow('Modbus ASCII LRC (纵向冗余校验):', _calculatedLrc),
                  const Divider(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('完整 Modbus RTU 报文 (含CRC校验):', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_fullAduHex.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('复制完整报文'),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _fullAduHex));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制完整报文到剪贴板')),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      _fullAduHex.isEmpty ? '<请输入有效Hex>' : _fullAduHex,
                      style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 14),
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

  // 2. Data Converter View
  Widget _buildConverterView() {
    final floatVal = double.tryParse(_floatInputCtrl.text.trim()) ?? 0.0;
    final regs = ModbusDataConverter.float32ToRegisters(floatVal);
    final rawWords = [regs.$1, regs.$2];
    final bytes = ModbusDataConverter.registersToBytes(rawWords);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('32位浮点数 (Float32) 四种字节序对照解析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _floatInputCtrl,
              decoration: const InputDecoration(
                labelText: '输入浮点数 (Float)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('字节序模式', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('排列方式', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('十六进制 (Hex Words)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('解析为浮点值', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: ModbusByteOrder.values.map((order) {
                final reordered = ModbusDataConverter.reorder32Bytes(bytes, order);
                final val = ByteData.sublistView(reordered).getFloat32(0, Endian.big);
                final hexDump = reordered.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

                return DataRow(
                  cells: [
                    DataCell(Text(order.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(order.label)),
                    DataCell(Text(hexDump, style: const TextStyle(fontFamily: 'monospace', color: Colors.indigo))),
                    DataCell(Text(val.toStringAsFixed(4), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Scanner View
  Widget _buildScannerView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _scanFromIdCtrl,
                  decoration: const InputDecoration(labelText: '起始从站ID', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _scanToIdCtrl,
                  decoration: const InputDecoration(labelText: '结束从站ID', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: Icon(_isScanning ? Icons.stop : Icons.search),
                label: Text(_isScanning ? '停止扫描' : '开始扫描从站'),
                onPressed: _isScanning ? () => _scannerService.stopScan() : _startSlaveScan,
              ),
            ],
          ),
        ),
        Expanded(
          child: _scanResults.isEmpty
              ? const Center(child: Text('输入从站ID范围并点击“开始扫描”即可自动发现网络中的 Modbus 设备'))
              : ListView.builder(
                  itemCount: _scanResults.length,
                  itemBuilder: (ctx, idx) {
                    final res = _scanResults[idx];
                    return ListTile(
                      leading: Icon(
                        res.isSuccess ? Icons.check_circle : Icons.cancel_outlined,
                        color: res.isSuccess ? Colors.green : Colors.grey,
                      ),
                      title: Text('从站 Unit ID: ${res.idOrAddress}  -  ${res.isSuccess ? "在线" : "离线"}'),
                      subtitle: Text(res.detail),
                      trailing: Text('${res.latencyMs} ms', style: const TextStyle(fontFamily: 'monospace')),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 4. Stress View
  Widget _buildStressView() {
    final rep = _stressReport;
    final progress = (rep != null && rep.totalRequests > 0)
        ? (rep.completedRequests / rep.totalRequests)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _stressCountCtrl,
                  decoration: const InputDecoration(labelText: '测试请求总次数', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                icon: Icon(_isStressRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isStressRunning ? '终止压测' : '启动稳定性与延迟基准压测'),
                onPressed: _isStressRunning ? () => _stressService.stop() : _startStressTest,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (rep != null) ...[
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 12),
            Text('测试进度: ${rep.completedRequests} / ${rep.totalRequests} (${(progress * 100).toStringAsFixed(1)}%)'),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('成功请求数:', '${rep.successCount} (成功率: ${rep.successRate.toStringAsFixed(2)}%)'),
                    const Divider(height: 16),
                    _infoRow('失败/超时数:', '${rep.errorCount} (丢包率: ${rep.errorRate.toStringAsFixed(2)}%)'),
                    const Divider(height: 16),
                    _infoRow('平均往返时延 (Avg Latency):', '${rep.avgLatencyMs.toStringAsFixed(2)} ms'),
                    const Divider(height: 16),
                    _infoRow('最低时延 (Min Latency):', '${rep.minLatencyMs == 999999 ? 0 : rep.minLatencyMs} ms'),
                    const Divider(height: 16),
                    _infoRow('最高时延 (Max Latency):', '${rep.maxLatencyMs} ms'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace', color: Colors.indigo, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
