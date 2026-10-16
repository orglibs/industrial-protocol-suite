import 'dart:async';
import 'package:flutter/material.dart';
import '../client/iec104_client.dart';
import '../client/traffic_logger.dart';
import '../client/workspace_storage.dart';
import 'tabs/connection_tab.dart';
import 'tabs/points_tab.dart';
import 'tabs/commands_tab.dart';
import 'tabs/traffic_tab.dart';
import 'tabs/parser_tab.dart';
import 'widgets/iec104_master_icon.dart';

class HomeScreen extends StatefulWidget {
  final Iec104Client client;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.client,
    this.onToggleTheme,
    this.isDarkMode = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final StreamSubscription<ClientConnectionState> _stateSub;
  StreamSubscription? _stationsSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationsSub = widget.client.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _stationsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.client;

    Color badgeColor = Colors.grey;
    if (c.state == ClientConnectionState.connecting) badgeColor = Colors.orange;
    if (c.state == ClientConnectionState.connected) badgeColor = Colors.blue;
    if (c.state == ClientConnectionState.active) badgeColor = Colors.green;

    int totalPoints = 0;
    for (final s in c.stations.values) {
      totalPoints += s.points.length;
    }

    final allTraffic = TrafficLogger.instance.entries;
    final rxCount = allTraffic.where((e) => e.direction == TrafficDirection.rx).length;
    final txCount = allTraffic.where((e) => e.direction == TrafficDirection.tx).length;

    final tabs = [
      ConnectionTab(client: c),
      PointsTab(client: c),
      CommandsTab(client: c),
      const TrafficTab(),
      const ParserTab(),
    ];

    final isConnected = c.state == ClientConnectionState.connected || c.state == ClientConnectionState.active;

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
              child: const Iec104MasterIcon(size: 20, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'IEC 60870-5-104 客户端仿真器 (Client Simulator)',
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
          // Connection Status indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badgeColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  c.state.label,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Fast Connect / Disconnect button
          FilledButton.tonalIcon(
            icon: Icon(
              isConnected ? Icons.link_off : Icons.link,
              size: 16,
              color: isConnected ? Colors.red : Colors.green,
            ),
            label: Text(isConnected ? '断开' : '连接'),
            onPressed: () async {
              if (isConnected) {
                await c.disconnect();
              } else {
                try {
                  await c.connect();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('连接失败: $e')),
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
            tooltip: '保存工作区 (${WorkspaceStorage.getWorkspaceFilePath()})',
            onPressed: () async {
              final ok = await c.saveWorkspace();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '工作区配置已保存至: ${WorkspaceStorage.getWorkspaceFilePath()}'
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
            selectedIndex: _currentIndex,
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Icon(Icons.device_hub, size: 28),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.settings_ethernet_outlined),
                selectedIcon: Icon(Icons.settings_ethernet),
                label: Text('连接主控'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.table_chart_outlined),
                selectedIcon: Icon(Icons.table_chart),
                label: Text('点位监视'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send),
                label: Text('命令下发'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('报文抓包'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.code_outlined),
                selectedIcon: Icon(Icons.code),
                label: Text('离线解析'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
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
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                c.state == ClientConnectionState.active
                    ? '通信链路已激活 (目标: ${c.host}:${c.port})'
                    : (c.state == ClientConnectionState.connected ? 'TCP已连通 (等待激活)' : '客户端已断开'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('从站(COA): ${c.stations.length} 个', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('点表总数: $totalPoints 点', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('RX 接收: $rxCount 帧', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Text('TX 发送: $txCount 帧', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('IEC 60870-5-104 客户端主站仿真', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
