import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/client_workspace_storage.dart';
import '../models/connection_config.dart';
import '../models/dictionary_service.dart';
import '../models/scl_parser.dart';
import '../protocol/iec61850_client_manager.dart';
import 'dialogs/create_connection_dialog.dart';
import 'tabs/data_monitor_tab.dart';
import 'tabs/files_and_settings_tab.dart';
import 'tabs/goose_tab.dart';
import 'tabs/model_explorer_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/scl_tools_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/iec61850_client_icon.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Iec61850ClientManager _manager = Iec61850ClientManager();
  int _selectedTabIndex = 0;
  bool _isConnecting = false;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _manager.addListener(_onManagerUpdate);
    _initWorkspace();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _manager.removeListener(_onManagerUpdate);
    _manager.dispose();
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initWorkspace() async {
    // 1. Load dictionaries
    await DictionaryService.instance.load();

    // 2. Load workspace storage
    final ws = await ClientWorkspaceStorage.loadWorkspace();
    for (final conn in ws.connections) {
      _manager.addConnection(conn);
      // Bind SCL if file exists
      if (conn.boundSclPath != null && conn.boundSclPath!.isNotEmpty) {
        try {
          final f = File(conn.boundSclPath!);
          if (f.existsSync()) {
            final res = SclParser.parseString(f.readAsStringSync());
            _manager.bindSclToConnection(conn, res);
          }
        } catch (_) {}
      }
    }

    if (_manager.connections.isEmpty) {
      final defaultConn = ConnectionConfig(
        id: 'conn_default',
        name: '本地测试服务端 (Local 127.0.0.1:102)',
        ip: '127.0.0.1',
        port: 102,
        boundSclPath: 'assets/examples/server_example_basic_io.icd',
      );
      _manager.addConnection(defaultConn);

      try {
        final f = File('assets/examples/server_example_basic_io.icd');
        if (f.existsSync()) {
          final res = SclParser.parseString(f.readAsStringSync());
          _manager.bindSclToConnection(defaultConn, res);
        }
      } catch (_) {}
    }

    // Bind default template to first connection if variables still empty
    final active = _manager.activeEngine;
    if (active != null && active.allVariables.isEmpty) {
      try {
        final f = File('assets/examples/server_example_basic_io.icd');
        if (f.existsSync()) {
          final res = SclParser.parseString(f.readAsStringSync());
          active.bindSclModel(res);
        }
      } catch (_) {}
    }

    if (mounted) setState(() {});
  }

  Future<void> _toggleConnection() async {
    final conn = _manager.selectedConnection;
    if (conn == null) return;

    if (conn.isConnected) {
      _manager.disconnect(conn);
    } else {
      setState(() => _isConnecting = true);
      final ok = await _manager.connect(conn);
      setState(() => _isConnecting = false);

      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              conn.statusMessage ?? '连接失败，请确认服务端已启动且端口 ${conn.port} 可访问',
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _openCreateConnectionDialog({ConnectionConfig? editConfig}) {
    showDialog(
      context: context,
      builder: (ctx) => CreateConnectionDialog(
        initialConfig: editConfig,
        onSaved: (cfg) {
          if (editConfig != null) {
            editConfig.name = cfg.name;
            editConfig.ip = cfg.ip;
            editConfig.port = cfg.port;
            editConfig.localTsap = cfg.localTsap;
            editConfig.remoteTsap = cfg.remoteTsap;
            editConfig.boundSclPath = cfg.boundSclPath;
            editConfig.autoConnect = cfg.autoConnect;
            editConfig.pollIntervalMs = cfg.pollIntervalMs;
            editConfig.notifyUpdated();
          } else {
            _manager.addConnection(cfg);
          }

          // If bound SCL changed, reload
          if (cfg.boundSclPath != null && cfg.boundSclPath!.isNotEmpty) {
            try {
              final f = File(cfg.boundSclPath!);
              if (f.existsSync()) {
                final res = SclParser.parseString(f.readAsStringSync());
                _manager.bindSclToConnection(cfg, res);
              }
            } catch (_) {}
          }

          ClientWorkspaceStorage.saveWorkspace(
            _manager.connections,
            _manager.activeEngine?.allVariables ?? [],
          );
          setState(() {});
        },
      ),
    );
  }

  void _deleteCurrentConnection() {
    final conn = _manager.selectedConnection;
    if (conn == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除连接配置'),
        content: Text('是否确认删除连接配置 "${conn.name}" (${conn.ip}:${conn.port})？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _manager.removeConnection(conn.id);
              ClientWorkspaceStorage.saveWorkspace(
                _manager.connections,
                _manager.activeEngine?.allVariables ?? [],
              );
              setState(() {});
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final conn = _manager.selectedConnection;
    final engine = _manager.activeEngine;
    final isConn = conn?.isConnected ?? false;

    return Scaffold(
      body: Column(
        children: [
          // 1. Top Industrial Connection & Status Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8ECEF),
              border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // App Logo & Title
                const Iec61850ClientIcon(size: 28, color: Color(0xFF0284C7), accentColor: Color(0xFF818CF8)),
                const SizedBox(width: 10),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IEC 61850 Client Simulator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                    ),
                    Text(
                      'MMS / COTP / GOOSE 工业电力客户端仿真器',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 24),

                // Connection Dropdown Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                  ),
                  child: DropdownButton<String>(
                    value: _manager.connections.any((c) => c.id == _manager.selectedConnectionId)
                        ? _manager.selectedConnectionId
                        : (_manager.connections.isNotEmpty ? _manager.connections.first.id : null),
                    underline: const SizedBox(),
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items: _manager.connections.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 10,
                              color: c.isConnected ? Colors.greenAccent : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${c.name} (${c.ip}:${c.port})',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setState(() {
                          _manager.selectedConnectionId = id;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),

                // Add Connection Button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
                  tooltip: '新建连接配置',
                  onPressed: () => _openCreateConnectionDialog(),
                ),
                // Edit Connection Button
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '编辑当前连接配置',
                  onPressed: conn != null ? () => _openCreateConnectionDialog(editConfig: conn) : null,
                ),
                // Delete Connection Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: '删除当前连接配置',
                  onPressed: _manager.connections.length > 1 ? _deleteCurrentConnection : null,
                ),

                const SizedBox(width: 12),

                // Connect / Disconnect Action Button
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isConn ? Colors.red[700] : Colors.green[700],
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(isConn ? Icons.power_settings_new : Icons.play_arrow),
                  label: Text(
                    isConn ? '断开连接' : '连接服务端',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: _isConnecting ? null : _toggleConnection,
                ),

                const Spacer(),

                // Status Chips
                _buildStatusChip(
                  label: 'TX',
                  value: '${conn?.txCount ?? 0}',
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: 'RX',
                  value: '${conn?.rxCount ?? 0}',
                  color: Colors.greenAccent,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  label: '点数',
                  value: '${engine?.allVariables.length ?? 0}',
                  color: Colors.purpleAccent,
                ),

                const SizedBox(width: 16),

                // Theme Toggle Button
                IconButton(
                  icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  tooltip: widget.isDarkMode ? '切换至亮色模式' : '切换至暗色模式',
                  onPressed: widget.onToggleTheme,
                ),
              ],
            ),
          ),

          // 2. Main Work Area: NavigationRail + Indexed Tab View
          Expanded(
            child: Row(
              children: [
                // Modern Navigation Rail
                NavigationRail(
                  selectedIndex: _selectedTabIndex,
                  labelType: NavigationRailLabelType.all,
                  minWidth: 76,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.account_tree_outlined),
                      selectedIcon: Icon(Icons.account_tree),
                      label: Text('模型浏览', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view),
                      label: Text('实时监视', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.mark_email_unread_outlined),
                      selectedIcon: Icon(Icons.mark_email_unread),
                      label: Text('报告控制', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.radar_outlined),
                      selectedIcon: Icon(Icons.radar),
                      label: Text('GOOSE监视', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.folder_shared_outlined),
                      selectedIcon: Icon(Icons.folder_shared),
                      label: Text('文件/定值', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.troubleshoot_outlined),
                      selectedIcon: Icon(Icons.troubleshoot),
                      label: Text('报文分析', style: TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books),
                      label: Text('SCL工具', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                  onDestinationSelected: (index) {
                    setState(() => _selectedTabIndex = index);
                  },
                ),

                const VerticalDivider(width: 1, thickness: 1),

                // Active Tab Content
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: [
                      ModelExplorerTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                      DataMonitorTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                      ReportsTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                      GooseTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                      FilesAndSettingsTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                      const TrafficTab(),
                      SclToolsTab(
                        manager: _manager,
                        onDataChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Industrial Status Bar
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF181818) : const Color(0xFFE0E0E0),
              border: Border(top: BorderSide(color: isDark ? Colors.grey[850]! : Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: isConn ? Colors.greenAccent : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  conn != null
                      ? '${conn.name} (${conn.ip}:${conn.port}) - ${conn.statusMessage ?? (isConn ? "已连接" : "未连接")}'
                      : '未选择连接',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
                const Spacer(),
                Text(
                  '轮询中: ${engine?.allVariables.where((v) => v.isPolling).length ?? 0} 项',
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 16),
                const Text(
                  '版本: v1.0.0',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(_now),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
