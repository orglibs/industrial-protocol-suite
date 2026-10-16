import 'package:flutter/material.dart';
import '../models/connection_config.dart';
import '../models/workspace_storage.dart';
import '../protocol/modbus_client.dart';
import '../services/polling_service.dart';
import 'dialogs/edit_connection_dialog.dart';
import 'dialogs/edit_slave_dialog.dart';
import 'tabs/register_view_tab.dart';
import 'tabs/connection_tab.dart';
import 'tabs/commands_tab.dart';
import 'tabs/traffic_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/chart_tab.dart';
import 'widgets/modbus_master_icon.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  late List<ConnectionConfig> _connections;
  late ConnectionConfig _activeConfig;
  late ModbusClient _client;
  late PollingService _pollingService;

  @override
  void initState() {
    super.initState();
    _client = ModbusClient();
    _initWorkspace();
  }

  Future<void> _initWorkspace() async {
    _connections = await WorkspaceStorage.loadConnections();
    _activeConfig = _connections.first;
    _pollingService = PollingService(client: _client, config: _activeConfig);
    _pollingService.updateConfig(_activeConfig);

    _client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });

    // If active config is virtual, connect automatically for great first-run experience
    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchActiveConnection(ConnectionConfig newConn) async {
    if (_client.state == ModbusConnectionState.connected) {
      _pollingService.stop();
      await _client.disconnect();
    }

    setState(() {
      _activeConfig = newConn;
      _pollingService.updateConfig(_activeConfig);
    });

    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

    await _saveWorkspace();
  }

  Future<void> _onAddConnection() async {
    final newConn = await EditConnectionDialog.show(
      context,
      defaultIndex: _connections.length + 1,
    );
    if (newConn != null) {
      setState(() {
        _connections.add(newConn);
      });
      await _switchActiveConnection(newConn);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加并切换至新连接: ${newConn.name}')),
        );
      }
    }
  }

  Future<void> _onDeleteConnection(ConnectionConfig conn) async {
    if (_connections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需保留一个通信连接配置，无法删除当前唯一连接。')),
      );
      return;
    }

    if (_client.state == ModbusConnectionState.connected && _activeConfig == conn) {
      _pollingService.stop();
      await _client.disconnect();
    }

    setState(() {
      _connections.remove(conn);
      if (_activeConfig == conn) {
        _activeConfig = _connections.first;
        _pollingService.updateConfig(_activeConfig);
      }
    });

    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

    await _saveWorkspace();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除连接: ${conn.name}')),
      );
    }
  }

  Future<void> _onAddSlaveToActiveConnection() async {
    final slave = await EditSlaveDialog.show(context);
    if (slave != null) {
      setState(() {
        _activeConfig.slaves.add(slave);
      });
      _onConfigChanged();
    }
  }

  Future<void> _saveWorkspace() async {
    await WorkspaceStorage.saveConnections(_connections);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('工程配置已保存至: ${WorkspaceStorage.defaultFilePath}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onConfigChanged() {
    _pollingService.updateConfig(_activeConfig);
    _saveWorkspace();
    setState(() {});
  }

  @override
  void dispose() {
    _pollingService.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在载入 Modbus Master 工作区配置...'),
            ],
          ),
        ),
      );
    }

    final isConnected = _client.state == ModbusConnectionState.connected;

    // Build connection label for app bar badge
    String peerBadge;
    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      peerBadge = '虚拟仿真运行中';
    } else if (isConnected) {
      if (_activeConfig.mode == ModbusTransportMode.serialRtu) {
        peerBadge = '已连接: ${_activeConfig.serialPortName ?? "串口"}';
      } else {
        peerBadge = '已连接: ${_activeConfig.ip}:${_activeConfig.port}';
      }
    } else {
      peerBadge = '未连接';
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
              child: const ModbusMasterIcon(size: 20, color: Color(0xFF10B981)),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Modbus Master Emulator (主站客户端仿真器)',
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
            const SizedBox(width: 12),

            // Connection selector dropdown in AppBar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.dividerColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ConnectionConfig>(
                  value: _activeConfig,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  items: _connections.map((c) {
                    final desc = c.mode == ModbusTransportMode.serialRtu
                        ? (c.serialPortName ?? '串口')
                        : (c.mode == ModbusTransportMode.virtual ? '虚拟' : '${c.ip}:${c.port}');
                    return DropdownMenuItem(
                      value: c,
                      child: Text('🔌 ${c.name} ($desc)'),
                    );
                  }).toList(),
                  onChanged: (newConn) {
                    if (newConn != null && newConn != _activeConfig) {
                      _switchActiveConnection(newConn);
                    }
                  },
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: '新建通信连接 (Add Connection)',
              onPressed: _onAddConnection,
            ),
          ],
        ),
        actions: [
          // Connection Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isConnected ? Colors.green : Colors.grey).withAlpha(38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isConnected ? Colors.green : Colors.grey),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isConnected ? Icons.check_circle : Icons.cancel, size: 14, color: isConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  peerBadge,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isConnected ? Colors.green : Colors.grey),
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
              final messenger = ScaffoldMessenger.of(context);
              if (isConnected) {
                _pollingService.stop();
                await _client.disconnect();
              } else {
                try {
                  await _client.connect();
                  if (_client.state == ModbusConnectionState.connected) {
                    _pollingService.start();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('连接失败: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),

          // Auto Polling toggle
          IconButton(
            icon: Icon(
              _pollingService.isRunning ? Icons.autorenew : Icons.pause_circle_outline,
              color: _pollingService.isRunning ? Colors.green : Colors.grey,
            ),
            tooltip: _pollingService.isRunning ? '轮询中 (点击暂停自动轮询)' : '已暂停 (点击恢复自动轮询)',
            onPressed: () {
              setState(() {
                if (_pollingService.isRunning) {
                  _pollingService.stop();
                } else {
                  _pollingService.start();
                }
              });
            },
          ),

          // Save Workspace button
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: '保存工程配置到本地',
            onPressed: _saveWorkspace,
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
              child: Icon(Icons.precision_manufacturing_outlined, size: 28),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: Text('寄存器视图'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_tree_outlined),
                selectedIcon: Icon(Icons.account_tree),
                label: Text('连接与从站'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.send_outlined),
                selectedIcon: Icon(Icons.send),
                label: Text('指令中心'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.sync_alt_outlined),
                selectedIcon: Icon(Icons.sync_alt),
                label: Text('报文监控'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.construction_outlined),
                selectedIcon: Icon(Icons.construction),
                label: Text('实用工具'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.show_chart_outlined),
                selectedIcon: Icon(Icons.show_chart),
                label: Text('趋势曲线'),
              ),
            ],
          ),

          const VerticalDivider(width: 1),

          // Tab content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                RegisterViewTab(
                  client: _client,
                  pollingService: _pollingService,
                  connections: _connections,
                  activeConnection: _activeConfig,
                  onSelectConnection: _switchActiveConnection,
                  onConfigChanged: _onConfigChanged,
                  onAddSlave: _onAddSlaveToActiveConnection,
                ),
                ConnectionTab(
                  client: _client,
                  pollingService: _pollingService,
                  connections: _connections,
                  activeConnection: _activeConfig,
                  onSelectConnection: _switchActiveConnection,
                  onConfigChanged: _onConfigChanged,
                  onAddConnection: _onAddConnection,
                  onDeleteConnection: _onDeleteConnection,
                ),
                CommandsTab(
                  client: _client,
                  config: _activeConfig,
                ),
                const TrafficTab(),
                ToolsTab(client: _client),
                ChartTab(
                  pollingService: _pollingService,
                  config: _activeConfig,
                ),
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
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(peerBadge, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('当前连接: ${_activeConfig.name}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('从站数量: ${_activeConfig.slaves.length} 个', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text(
                _pollingService.isRunning
                    ? '自动轮询中 (${_activeConfig.pollingIntervalMs}ms)'
                    : '自动轮询已暂停',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('Modbus RTU / TCP / UDP 主站客户端仿真', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
