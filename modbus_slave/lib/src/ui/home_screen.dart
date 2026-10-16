import 'package:flutter/material.dart';
import '../models/connection_config.dart';
import '../models/workspace_storage.dart';
import '../protocol/modbus_server.dart';
import '../services/simulation_service.dart';
import 'tabs/chart_tab.dart';
import 'tabs/register_view_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/topology_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/modbus_slave_icon.dart';

class HomeScreen extends StatefulWidget {
  final List<ConnectionConfig> initialConnections;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.initialConnections,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<ConnectionConfig> _connections;

  @override
  void initState() {
    super.initState();
    _connections = widget.initialConnections;
    // Set connections into simulation service
    SimulationService.instance.setConnections(_connections);

    // Auto-save on changes
    for (final c in _connections) {
      c.addListener(_onConnUpdated);
    }
  }

  void _onConnUpdated() {
    if (mounted) setState(() {});
  }

  void _saveWorkspace() async {
    await WorkspaceStorage.saveConnections(_connections);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('工作区配置已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSimRunning = SimulationService.instance.isRunning;

    int activeServers = 0;
    int totalClients = 0;
    int totalRx = 0;
    int totalTx = 0;

    for (final c in _connections) {
      if (c.isRunning) activeServers++;
      totalClients += c.clientCount;
      totalRx += c.rxCount;
      totalTx += c.txCount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF10B981), width: 1.2),
              ),
              child: const ModbusSlaveIcon(size: 20, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Text(
              'Modbus Slave Emulator (从站服务端模拟器)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
          // Wave Simulation Quick Toggle
          FilledButton.tonalIcon(
            icon: Icon(
              isSimRunning ? Icons.waves : Icons.blur_linear,
              size: 16,
              color: isSimRunning ? Colors.green : Colors.grey,
            ),
            label: Text(isSimRunning ? '波形模拟中' : '启动波形模拟'),
            onPressed: () {
              SimulationService.instance.setConnections(_connections);
              SimulationService.instance.toggle();
              setState(() {});
            },
          ),
          const SizedBox(width: 8),
          // Start All
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: Colors.green),
            tooltip: '一键启动所有连接服务',
            onPressed: () async {
              await ModbusServerManager.instance.startAll(_connections);
              setState(() {});
            },
          ),
          // Stop All
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            tooltip: '一键停止所有连接服务',
            onPressed: () async {
              await ModbusServerManager.instance.stopAll(_connections);
              setState(() {});
            },
          ),
          // Save Workspace
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存工作区配置',
            onPressed: _saveWorkspace,
          ),
          // Theme Toggle
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
          // Left NavigationRail
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
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: Text('寄存器监视'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_tree_outlined),
                selectedIcon: Icon(Icons.account_tree),
                label: Text('连接与从站'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sync_alt_outlined),
                selectedIcon: Icon(Icons.sync_alt),
                label: Text('通信报文'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: Text('实时曲线'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.construction_outlined),
                selectedIcon: Icon(Icons.construction),
                label: Text('辅助工具'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                RegisterViewTab(
                  connections: _connections,
                  onDataChanged: () => setState(() {}),
                ),
                TopologyTab(
                  connections: _connections,
                  onDataChanged: () => setState(() {}),
                ),
                const TrafficTab(),
                ChartTab(connections: _connections),
                const ToolsTab(),
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
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 8,
              color: activeServers > 0 ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              activeServers > 0 ? '服务运行中 ($activeServers 个连接监听)' : '所有服务端已停止',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 20),
            Text('连接主站数: $totalClients', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 20),
            Text('RX 接收: $totalRx 帧', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            Text('TX 发送: $totalTx 帧', style: const TextStyle(fontSize: 12)),
            const Spacer(),
            if (isSimRunning)
              const Row(
                children: [
                  Icon(Icons.waves, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text('数据模拟运行中', style: TextStyle(fontSize: 12, color: Colors.green)),
                  SizedBox(width: 16),
                ],
              ),
            Text('Modbus RTU / TCP / UDP 从站仿真', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
