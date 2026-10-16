import "../../i18n/app_i18n.dart";
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
          SnackBar(content: Text("${AppI18n.instance.t('parseError')}: $e"), backgroundColor: Colors.red),
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
              Text('IEC 104 Self-Test Results'),
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
                final isSuccess = !text.contains('FAIL');
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
              child: Text(AppI18n.instance.t('confirm')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppI18n.instance.t('parseError')}: $e"), backgroundColor: Colors.red),
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
                                ? (widget.server.isWebVirtualMode ? 'IEC 104 Service Running (Web Virtual)' : 'IEC 104 Service Running')
                                : 'IEC 104 Service Stopped',
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
                                    ? 'Web Virtual Mode | Clients: ${clients.length}'
                                    : 'TCP: ${widget.server.host}:${widget.server.port} | Clients: ${clients.length}')
                                : 'Server stopped. Click Start to listen.',
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
                      icon: Icon(Icons.verified, color: theme.colorScheme.primary),
                      label: const Text('Self-Test'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isRunning ? Colors.red.shade600 : Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _isLoading ? null : _toggleServer,
                      icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(isRunning ? AppI18n.instance.t('stopListen') : AppI18n.instance.t('startListen')),
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
                        'Web environment uses virtual loopback simulation. For native TCP 2404 listening, run desktop executable: ./build/iec104_server',
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
                    Text(AppI18n.instance.t('serverNetworkConfig'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hostController,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: AppI18n.instance.t('listenIp'),
                              border: OutlineInputBorder(),
                              helperText: '0.0.0.0 | 127.0.0.1',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            enabled: !isRunning,
                            decoration: InputDecoration(
                              labelText: AppI18n.instance.t('listenPort'),
                              border: OutlineInputBorder(),
                              helperText: 'Default: 2404',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('IEC 60870-5-104 Timers & Windowing:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _t0Controller,
                            enabled: !isRunning,
                            decoration: InputDecoration(labelText: 't0: Connect Timeout (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t1Controller,
                            enabled: !isRunning,
                            decoration: InputDecoration(labelText: 't1: Send Timeout (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t2Controller,
                            enabled: !isRunning,
                            decoration: InputDecoration(labelText: 't2: Ack Timeout (s)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _t3Controller,
                            enabled: !isRunning,
                            decoration: InputDecoration(labelText: 't3: Test Frame (s)', border: OutlineInputBorder()),
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
                            decoration: InputDecoration(labelText: 'k: Max Unack Frames', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _wController,
                            enabled: !isRunning,
                            decoration: InputDecoration(labelText: 'w: Ack Threshold', border: OutlineInputBorder()),
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
                            decoration: InputDecoration(labelText: 'COT Size', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 Byte')),
                              DropdownMenuItem(value: 2, child: Text('2 Bytes (Standard)')),
                            ],
                            onChanged: isRunning ? null : (v) => widget.server.cotSize = v!,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: widget.server.ioaSize,
                            isExpanded: true,
                            decoration: InputDecoration(labelText: 'IOA Size', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 2, child: Text('2 Bytes')),
                              DropdownMenuItem(value: 3, child: Text('3 Bytes (Standard)')),
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
                        Text("${AppI18n.instance.t('connectedMasters')} (${clients.length})",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if (clients.isNotEmpty)
                          TextButton.icon(
                            icon: const Icon(Icons.link_off, size: 18),
                            label: Text(AppI18n.instance.t('closeAll')),
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
                          isRunning ? 'Waiting for client connections...' : 'Server stopped',
                          style: TextStyle(color: theme.colorScheme.outline),
                        ),
                      )
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceVariant.withOpacity(0.35)),
                          headingRowHeight: 40,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 44,
                          columns: [
                            DataColumn(label: const Text('Client ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: const Text('Remote Address', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: const Text('STARTDT State', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: const Text('N(S)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: const Text('N(R)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text(AppI18n.instance.t('operation'), style: const TextStyle(fontWeight: FontWeight.bold))),
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
                                    c.isDataTransferActive ? 'ACTIVE (STARTDT)' : 'PENDING',
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
                                  tooltip: AppI18n.instance.t('disconnect'),
                                  onPressed: () => c.close(),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
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
