import 'dart:async';
import 'package:flutter/material.dart';
import '../server/iec104_server.dart';
import '../server/workspace_storage.dart';
import 'tabs/auto_sim_tab.dart';
import 'tabs/parser_tab.dart';
import 'tabs/server_tab.dart';
import 'tabs/station_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/iec104_slave_icon.dart';

class HomeScreen extends StatefulWidget {
  final Iec104Server server;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.server,
    this.onToggleTheme,
    this.isDarkMode = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _statusSub;
  StreamSubscription? _stationSub;
  StreamSubscription? _clientSub;

  @override
  void initState() {
    super.initState();
    _statusSub = widget.server.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationSub = widget.server.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
    _clientSub = widget.server.clientsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _stationSub?.cancel();
    _clientSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = widget.server.isRunning;

    int totalPoints = 0;
    int autoSimCount = 0;
    for (final s in widget.server.stations.values) {
      totalPoints += s.points.length;
      autoSimCount += s.points.values.where((p) => p.autoChangeEnabled).length;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981), width: 1.2),
              ),
              child: const Iec104SlaveIcon(size: 20, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'IEC 60870-5-104 Server Simulator',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('v1.0.0', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        actions: [
          // Quick Start / Stop Toggle
          FilledButton.tonalIcon(
            icon: Icon(
              isRunning ? Icons.stop : Icons.play_arrow,
              size: 16,
              color: isRunning ? Colors.red : Colors.green,
            ),
            label: Text(isRunning ? '停止监听' : '启动监听'),
            onPressed: () async {
              if (isRunning) {
                await widget.server.stop();
              } else {
                try {
                  await widget.server.start();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('启动服务失败: $e')),
                    );
                  }
                }
              }
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),
          // Save Workspace Button
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存服务端工作区 (${WorkspaceStorage.getWorkspaceFilePath()})',
            onPressed: () async {
              final ok = await widget.server.saveWorkspace();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '服务端工作区配置已保存至: ${WorkspaceStorage.getWorkspaceFilePath()}'
                        : '保存失败'),
                    backgroundColor: ok ? Colors.green : Colors.red,
                  ),
                );
              }
            },
          ),
          // Theme Toggle Button
          if (widget.onToggleTheme != null)
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              tooltip: widget.isDarkMode ? '切换为亮色模式' : '切换为暗色模式',
              onPressed: widget.onToggleTheme,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Left NavigationRail matching modbus_slave style
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.device_hub, size: 28),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.settings_ethernet_outlined),
                selectedIcon: Icon(Icons.settings_ethernet),
                label: Text('服务配置与主站'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.view_list_outlined),
                selectedIcon: Icon(Icons.view_list),
                label: Text('点位监视与控制'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.swap_horiz_outlined),
                selectedIcon: Icon(Icons.swap_horiz),
                label: Text('通信细节报文'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: Text('报文解析工具'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: Text('变化模拟配置'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ServerTab(server: widget.server),
                StationTab(server: widget.server),
                const TrafficTab(),
                const ParserTab(),
                AutoSimTab(server: widget.server),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
          border: Border(top: BorderSide(color: theme.dividerColor)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: isRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                isRunning ? '服务运行中 (监听端口: ${widget.server.port})' : '所有服务端已停止',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('连接主站数: ${widget.server.clients.length}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('从站(COA): ${widget.server.stations.length} 个', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('总监视点位: $totalPoints 点', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              if (autoSimCount > 0) ...[
                const Icon(Icons.waves, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('$autoSimCount 个点位模拟中', style: const TextStyle(fontSize: 12, color: Colors.green)),
                const SizedBox(width: 20),
              ],
              Text('IEC 60870-5-104 服务端仿真', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
