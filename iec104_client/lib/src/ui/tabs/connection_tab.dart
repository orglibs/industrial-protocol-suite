import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/traffic_logger.dart';

class ConnectionTab extends StatefulWidget {
  final Iec104Client client;

  const ConnectionTab({super.key, required this.client});

  @override
  State<ConnectionTab> createState() => _ConnectionTabState();
}

class _ConnectionTabState extends State<ConnectionTab> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _caCtrl;
  late TextEditingController _kCtrl;
  late TextEditingController _wCtrl;
  late TextEditingController _t0Ctrl;
  late TextEditingController _t1Ctrl;
  late TextEditingController _t2Ctrl;
  late TextEditingController _t3Ctrl;

  late TextEditingController _giPeriodCtrl;
  late TextEditingController _clockPeriodCtrl;
  late TextEditingController _counterPeriodCtrl;

  bool _isVerifying = false;
  List<String>? _verifyResults;

  StreamSubscription<ClientConnectionState>? _stateSub;
  StreamSubscription<TrafficEntry>? _trafficSub;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _hostCtrl = TextEditingController(text: c.host);
    _portCtrl = TextEditingController(text: c.port.toString());
    _caCtrl = TextEditingController(text: c.defaultCa.toString());
    _kCtrl = TextEditingController(text: c.k.toString());
    _wCtrl = TextEditingController(text: c.w.toString());
    _t0Ctrl = TextEditingController(text: c.t0.toString());
    _t1Ctrl = TextEditingController(text: c.t1.toString());
    _t2Ctrl = TextEditingController(text: c.t2.toString());
    _t3Ctrl = TextEditingController(text: c.t3.toString());

    _giPeriodCtrl = TextEditingController(text: c.generalInterrogationPeriod.toString());
    _clockPeriodCtrl = TextEditingController(text: c.clockSyncPeriod.toString());
    _counterPeriodCtrl = TextEditingController(text: c.counterInterrogationPeriod.toString());

    _stateSub = widget.client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _trafficSub = TrafficLogger.instance.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _trafficSub?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _caCtrl.dispose();
    _kCtrl.dispose();
    _wCtrl.dispose();
    _t0Ctrl.dispose();
    _t1Ctrl.dispose();
    _t2Ctrl.dispose();
    _t3Ctrl.dispose();
    _giPeriodCtrl.dispose();
    _clockPeriodCtrl.dispose();
    _counterPeriodCtrl.dispose();
    super.dispose();
  }

  void _applyParams() {
    final c = widget.client;
    c.host = _hostCtrl.text.trim();
    c.port = int.tryParse(_portCtrl.text.trim()) ?? 2404;
    c.defaultCa = int.tryParse(_caCtrl.text.trim()) ?? 1;
    c.k = int.tryParse(_kCtrl.text.trim()) ?? 12;
    c.w = int.tryParse(_wCtrl.text.trim()) ?? 8;
    c.t0 = int.tryParse(_t0Ctrl.text.trim()) ?? 30;
    c.t1 = int.tryParse(_t1Ctrl.text.trim()) ?? 15;
    c.t2 = int.tryParse(_t2Ctrl.text.trim()) ?? 10;
    c.t3 = int.tryParse(_t3Ctrl.text.trim()) ?? 20;

    c.generalInterrogationPeriod = int.tryParse(_giPeriodCtrl.text.trim()) ?? 0;
    c.clockSyncPeriod = int.tryParse(_clockPeriodCtrl.text.trim()) ?? 0;
    c.counterInterrogationPeriod = int.tryParse(_counterPeriodCtrl.text.trim()) ?? 0;
    c.scheduleAutoSave();
  }

  Future<void> _runVerification() async {
    setState(() {
      _isVerifying = true;
      _verifyResults = null;
    });

    try {
      final res = await widget.client.runAutomatedVerification();
      if (mounted) {
        setState(() {
          _verifyResults = res;
          _isVerifying = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _verifyResults = ['验证异常: $e'];
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final isConnected = c.state != ClientConnectionState.disconnected;
    final isActive = c.state == ClientConnectionState.active;

    Color badgeColor = Colors.grey;
    if (c.state == ClientConnectionState.connecting) badgeColor = Colors.orange;
    if (c.state == ClientConnectionState.connected) badgeColor = Colors.blue;
    if (c.state == ClientConnectionState.active) badgeColor = Colors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection Status Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '连接状态: ${c.state.label}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('N(S): ${c.sendSeq} | N(R): ${c.recvSeq} | 未确认: ${c.unconfirmedRecvCount}'),
                      if (c.isWebVirtualMode) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade700),
                          ),
                          child: const Text('Web 虚拟测试模式', style: TextStyle(color: Colors.brown, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isConnected)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.link),
                          label: const Text('建立连接 (Connect)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            _applyParams();
                            try {
                              await c.connect();
                              setState(() {});
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('连接失败: $e')),
                                );
                              }
                            }
                          },
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.link_off),
                          label: const Text('断开连接 (Disconnect)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await c.disconnect();
                            setState(() {});
                          },
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('STARTDT (激活数据)'),
                        onPressed: isConnected ? () => c.sendStartDt() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('STOPDT (停止数据)'),
                        onPressed: isConnected ? () => c.sendStopDt() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('TESTFR (链路保活)'),
                        onPressed: isConnected ? () => c.sendTestFr() : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.done_all),
                        label: const Text('发送 S 确认帧'),
                        onPressed: isConnected ? () => c.sendSFrame() : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.sync),
                        label: const Text('下发总召唤 (C_IC_NA_1)'),
                        onPressed: isActive ? () => c.sendGeneralInterrogation() : null,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.access_time),
                        label: const Text('时钟同步 (C_CS_NA_1)'),
                        onPressed: isActive ? () => c.sendClockSynchronization() : null,
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.flash_on),
                        label: const Text('电能量总召 (C_CI_NA_1)'),
                        onPressed: isActive ? () => c.sendCounterInterrogation() : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Network Parameters Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('网络与连接参数 (Connection Configuration)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: const InputDecoration(
                            labelText: '服务端 IP 地址 (Host)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.computer),
                          ),
                          enabled: !isConnected,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _portCtrl,
                          decoration: const InputDecoration(
                            labelText: '端口 (Port)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                          enabled: !isConnected,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _caCtrl,
                          decoration: const InputDecoration(
                            labelText: '默认从站公共地址 (COA)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_city),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('IEC 60870-5-104 传输层定时器与窗口参数', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kCtrl,
                          decoration: const InputDecoration(labelText: 'k 发送窗口', border: OutlineInputBorder(), helperText: '最大未确认发送'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _wCtrl,
                          decoration: const InputDecoration(labelText: 'w 接收窗口', border: OutlineInputBorder(), helperText: '最大未确认接收'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t0Ctrl,
                          decoration: const InputDecoration(labelText: 't0 超时 (s)', border: OutlineInputBorder(), helperText: 'TCP连接超时'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t1Ctrl,
                          decoration: const InputDecoration(labelText: 't1 超时 (s)', border: OutlineInputBorder(), helperText: 'APDU确认超时'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t2Ctrl,
                          decoration: const InputDecoration(labelText: 't2 超时 (s)', border: OutlineInputBorder(), helperText: 'S帧回复延迟'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t3Ctrl,
                          decoration: const InputDecoration(labelText: 't3 保活 (s)', border: OutlineInputBorder(), helperText: '空闲测试心跳'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Automation Settings
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('高级自动化任务与周期轮询 (Automatic Tasks)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('连接建立后自动发送 STARTDT act (Auto STARTDT)'),
                    value: c.autoStartDt,
                    onChanged: (val) => setState(() => c.autoStartDt = val),
                  ),
                  SwitchListTile(
                    title: const Text('链路激活后自动执行总召唤 (Auto General Interrogation)'),
                    value: c.autoGeneralInterrogation,
                    onChanged: (val) => setState(() => c.autoGeneralInterrogation = val),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _giPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: '周期总召唤间隔 (秒)',
                            helperText: '0 表示禁用',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _clockPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: '周期时钟同步间隔 (秒)',
                            helperText: '0 表示禁用',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _counterPeriodCtrl,
                          decoration: const InputDecoration(
                            labelText: '周期电能量召唤间隔 (秒)',
                            helperText: '0 表示禁用',
                            border: OutlineInputBorder(),
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

          // Automated Verification Card
          Card(
            elevation: 2,
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        '客户端全功能自动化一键验证',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        icon: _isVerifying
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow),
                        label: Text(_isVerifying ? '正在验证...' : '运行自动化测试'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isVerifying ? null : _runVerification,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('自动按序测试：连接创建 -> STARTDT握手 -> 总召唤解析 -> 时钟对时 -> 遥控预置与执行 -> 电能量总召 -> 单点读取 -> S确认对齐 -> 心跳保活 -> 正常断开。'),
                  if (_verifyResults != null) ...[
                    const Divider(height: 24),
                    for (final r in _verifyResults!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              r.contains('失败') ? Icons.cancel : Icons.check_circle,
                              size: 18,
                              color: r.contains('失败') ? Colors.red : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r,
                                style: TextStyle(
                                  color: r.contains('失败') ? Colors.red.shade900 : Colors.green.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
