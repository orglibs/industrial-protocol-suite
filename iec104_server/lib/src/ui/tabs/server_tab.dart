import 'package:flutter/material.dart';
import '../../server/client_session.dart';
import '../../server/iec104_server.dart';

class ServerTab extends StatefulWidget {
  final Iec104Server server;

  const ServerTab({super.key, required this.server});

  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _t0Controller;
  late TextEditingController _t1Controller;
  late TextEditingController _t2Controller;
  late TextEditingController _t3Controller;
  late TextEditingController _kController;
  late TextEditingController _wController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.server.host);
    _portController = TextEditingController(text: widget.server.port.toString());
    _t0Controller = TextEditingController(text: widget.server.t0.toString());
    _t1Controller = TextEditingController(text: widget.server.t1.toString());
    _t2Controller = TextEditingController(text: widget.server.t2.toString());
    _t3Controller = TextEditingController(text: widget.server.t3.toString());
    _kController = TextEditingController(text: widget.server.k.toString());
    _wController = TextEditingController(text: widget.server.w.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _t0Controller.dispose();
    _t1Controller.dispose();
    _t2Controller.dispose();
    _t3Controller.dispose();
    _kController.dispose();
    _wController.dispose();
    super.dispose();
  }

  Future<void> _toggleServer() async {
    setState(() => _isLoading = true);
    try {
      if (widget.server.isRunning) {
        await widget.server.stop();
      } else {
        widget.server.host = _hostController.text.trim();
        widget.server.port = int.tryParse(_portController.text.trim()) ?? 2404;
        widget.server.t0 = int.tryParse(_t0Controller.text.trim()) ?? 30;
        widget.server.t1 = int.tryParse(_t1Controller.text.trim()) ?? 15;
        widget.server.t2 = int.tryParse(_t2Controller.text.trim()) ?? 10;
        widget.server.t3 = int.tryParse(_t3Controller.text.trim()) ?? 20;
        widget.server.k = int.tryParse(_kController.text.trim()) ?? 12;
        widget.server.w = int.tryParse(_wController.text.trim()) ?? 8;

        await widget.server.start();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runVerification() async {
    setState(() => _isLoading = true);
    try {
      final results = await widget.server.runAutomatedVerification();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 8),
              Text('IEC 104 功能自动验证结果'),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final text = results[i];
                final isSuccess = !text.contains('失败');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('验证出错: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRunning = widget.server.isRunning;

    return StreamBuilder<List<ClientSession>>(
      stream: widget.server.clientsStream,
      initialData: widget.server.clients,
      builder: (context, snapshot) {
        final clients = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Status Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              color: isRunning
                  ? (isDark ? const Color(0xFF132F24) : Colors.green.shade50)
                  : (isDark ? const Color(0xFF25252D) : Colors.grey.shade100),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      isRunning ? Icons.check_circle : Icons.stop_circle,
                      size: 48,
                      color: isRunning ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRunning
                                ? (widget.server.isWebVirtualMode ? 'IEC 104 仿真服务正在运行 (Web 虚拟模式)' : 'IEC 104 服务正在运行')
                                : 'IEC 104 服务已停止',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isRunning
                                  ? (isDark ? Colors.greenAccent : Colors.green.shade900)
                                  : theme.textTheme.titleLarge?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRunning
                                ? (widget.server.isWebVirtualMode
                                    ? 'Web 浏览器沙箱环境：已激活虚拟服务端链路 | 在线客户端: ${clients.length}'
                                    : '原生 TCP 监听: ${widget.server.host}:${widget.server.port} | 在线主站连接: ${clients.length}')
                                : '未启动服务，配置参数后点击右侧按钮启动监听。',
                            style: TextStyle(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _runVerification,
                      icon: const Icon(Icons.verified, color: Colors.blue),
                      label: const Text('自动验证功能'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning ? Colors.red.shade600 : Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _toggleServer,
                      icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(isRunning ? '停止服务' : '启动服务'),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.server.isWebVirtualMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF332A16) : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF7A5813) : Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: isDark ? Colors.amberAccent : Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '提示：Web 浏览器受安全沙箱限制无法直接监听操作系统原生 TCP 端口 (2404)。当前已自动为您启用内置虚拟从站与协议模拟器！'
                        '如需作为真正的原生网络服务端对外开放 2404 端口供外部物理设备连接，请在 Linux/Windows 桌面终端运行已生成的独立二进制: ./build/iec104_server',
                        style: TextStyle(color: isDark ? Colors.amberAccent : Colors.amber.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Server Network & Protocol Settings
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('服务网络与链路参数配置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostController,
                            enabled: !isRunning,
                            decoration: const InputDecoration(
                              labelText: '绑定监听 IP (Host)',
                              border: OutlineInputBorder(),
                              helperText: '0.0.0.0 (所有网卡) 或 127.0.0.1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            enabled: !isRunning,
                            decoration: const InputDecoration(
                              labelText: '服务端口 (Port)',
                              border: OutlineInputBorder(),
                              helperText: '默认 2404',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('IEC 60870-5-104 超时与窗口参数 (Timers & Windowing):',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _t0Controller,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 't0: 连接超时 (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t1Controller,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 't1: 发送超时 (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t2Controller,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 't2: 确认超时 (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t3Controller,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 't3: 心跳间隔 (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _kController,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 'k: 最大未确认帧数', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _wController,
                            enabled: !isRunning,
                            decoration: const InputDecoration(labelText: 'w: 最新确认帧数', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: widget.server.cotSize,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'COT 长度', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 字节')),
                              DropdownMenuItem(value: 2, child: Text('2 字节 (标准)')),
                            ],
                            onChanged: isRunning ? null : (v) => widget.server.cotSize = v!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: widget.server.ioaSize,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'IOA 长度', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 2, child: Text('2 字节')),
                              DropdownMenuItem(value: 3, child: Text('3 字节 (标准)')),
                            ],
                            onChanged: isRunning ? null : (v) => widget.server.ioaSize = v!,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Connected Clients Table
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('已连接主站客户端 (${clients.length})',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (clients.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.link_off, size: 18),
                            label: const Text('断开全部'),
                            onPressed: () {
                              for (final c in List.from(clients)) {
                                c.close();
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (clients.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: Text(
                          isRunning ? '等待主站客户端连接...' : '服务未启动',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('客户端ID')),
                          DataColumn(label: Text('远程地址 (IP:Port)')),
                          DataColumn(label: Text('数据传输状态 (STARTDT)')),
                          DataColumn(label: Text('发送序号 N(S)')),
                          DataColumn(label: Text('接收序号 N(R)')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: clients.map((c) {
                          return DataRow(cells: [
                            DataCell(Text('#${c.sessionId}')),
                            DataCell(Text(c.remoteAddress, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (c.isDataTransferActive ? Colors.green : Colors.amber).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: (c.isDataTransferActive ? Colors.green : Colors.amber).withOpacity(0.5)),
                                ),
                                child: Text(
                                  c.isDataTransferActive ? '已激活 (STARTDT Con)' : '未激活 (Pending)',
                                  style: TextStyle(
                                    color: c.isDataTransferActive ? Colors.green : Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text('${c.txSeq}')),
                            DataCell(Text('${c.rxSeq}')),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                tooltip: '断开此连接',
                                onPressed: () => c.close(),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
