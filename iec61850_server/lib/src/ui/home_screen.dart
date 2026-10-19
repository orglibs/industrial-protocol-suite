import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../models/dictionary_service.dart';
import '../models/scl_parser.dart';
import '../models/server_config.dart';
import '../models/workspace_storage.dart';
import '../protocol/iec61850_server_manager.dart';
import 'dialogs/edit_server_dialog.dart';
import 'tabs/data_monitor_tab.dart';
import 'tabs/files_and_settings_tab.dart';
import 'tabs/goose_tab.dart';
import 'tabs/model_explorer_tab.dart';
import 'tabs/reports_tab.dart';
import 'tabs/scl_tools_tab.dart';
import 'tabs/traffic_tab.dart';
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final List<ServerConfig>? initialConnections;
  final Iec61850ServerManager? manager;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    this.initialConnections,
    this.manager,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<ServerConfig> _connections;
  ServerConfig? _activeConnection;

  int _selectedTabIndex = 0;
  Timer? _uiRefreshTimer;
  DateTime _now = DateTime.now();

  ServerConfig get currentConnection {
    if (_activeConnection != null && _connections.contains(_activeConnection)) {
      return _activeConnection!;
    }
    if (_connections.isNotEmpty) {
      return _connections.first;
    }
    return _fallbackConfig;
  }

  late final ServerConfig _fallbackConfig;
  Iec61850ServerManager get currentManager => currentConnection.manager;

  @override
  void initState() {
    super.initState();
    _fallbackConfig = ServerConfig(
      name: 'IEC 61850 MMS Server',
      ip: '0.0.0.0',
      port: 102,
    );

    _initConnections();
    _initAsync();

    // UI Clock & counters refresh timer
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  void _initConnections() {
    if (widget.initialConnections != null && widget.initialConnections!.isNotEmpty) {
      _connections = List.from(widget.initialConnections!);
    } else if (widget.manager != null) {
      _connections = [widget.manager!.config];
    } else {
      _connections = ServerConfig.createDefaultConnections();
    }
    _activeConnection = _connections.isNotEmpty ? _connections.first : _fallbackConfig;
    _listenToConnections();
  }

  void _onServerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _listenToConnections() {
    for (final c in _connections) {
      c.removeListener(_onServerUpdate);
      c.manager.removeListener(_onServerUpdate);
      c.addListener(_onServerUpdate);
      c.manager.addListener(_onServerUpdate);
    }
  }

  Future<void> _initAsync() async {
    // 1. Load dictionary
    await DictionaryService.instance.load();

    // 2. Load workspace storage if initialConnections not provided explicitly
    if (widget.initialConnections == null && widget.manager == null) {
      final savedConnections = await WorkspaceStorage.loadConnections();
      if (savedConnections.isNotEmpty) {
        setState(() {
          _connections = savedConnections;
          _activeConnection = _connections.first;
          _listenToConnections();
        });
      }
    }

    // 3. Load SCL ICD files for all connections that have a path configured
    for (final c in _connections) {
      await _loadSclForConnection(c);
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadSclForConnection(ServerConfig conn) async {
    if (conn.manager.engine.scl != null) return;
    if (conn.sclFilePath == null || conn.sclFilePath!.isEmpty) return;

    final candidatePaths = [
      conn.sclFilePath!,
      'iec61850_server/${conn.sclFilePath!}',
      '../iec61850_server/${conn.sclFilePath!}',
      '/home/douqi/workspaces/nixiangwork/iec104serversimulator/iec61850_server/${conn.sclFilePath!}',
    ];

    for (final p in candidatePaths) {
      final f = File(p);
      if (f.existsSync()) {
        try {
          final parseRes = SclParser.parse(f.readAsStringSync());
          conn.manager.loadScl(parseRes);
          return;
        } catch (_) {}
      }
    }

    if (mounted) {
      try {
        final content = await DefaultAssetBundle.of(context).loadString(conn.sclFilePath!);
        final parseRes = SclParser.parse(content);
        conn.manager.loadScl(parseRes);
        return;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    for (final c in _connections) {
      c.removeListener(_onServerUpdate);
      c.manager.removeListener(_onServerUpdate);
      c.manager.stopServer();
    }
    super.dispose();
  }

  Future<void> _saveWorkspace() async {
    await WorkspaceStorage.saveConnections(_connections);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppI18n.instance.t('saveWorkspace')} -> ${WorkspaceStorage.defaultFilePath}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openAddServerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EditServerDialog(
        config: null,
        onSaved: (newCfg) async {
          setState(() {
            _connections.add(newCfg);
            _activeConnection = newCfg;
            _listenToConnections();
          });
          await _loadSclForConnection(newCfg);
        },
      ),
    );
  }

  void _openEditServerDialog(ServerConfig cfg) {
    showDialog(
      context: context,
      builder: (ctx) => EditServerDialog(
        config: cfg,
        onSaved: (updatedCfg) {
          setState(() {});
          if (updatedCfg.isRunning) {
            updatedCfg.manager.restartServer();
          }
        },
        onDelete: _connections.length > 1
            ? () {
                setState(() {
                  cfg.manager.stopServer();
                  _connections.remove(cfg);
                  _activeConnection = _connections.first;
                });
              }
            : null,
      ),
    );
  }

  NavigationRailDestination _buildRailDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String labelText,
  }) {
    return NavigationRailDestination(
      icon: Tooltip(
        message: labelText,
        waitDuration: const Duration(milliseconds: 300),
        child: Icon(icon),
      ),
      selectedIcon: Tooltip(
        message: labelText,
        waitDuration: const Duration(milliseconds: 300),
        child: Icon(selectedIcon),
      ),
      label: Tooltip(
        message: labelText,
        waitDuration: const Duration(milliseconds: 300),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 72),
          child: Text(
            labelText,
            textAlign: TextAlign.center,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final i18n = AppI18n.instance;

    int activeServers = 0;
    int totalClients = 0;
    int totalRx = 0;
    int totalTx = 0;
    int totalGoose = 0;

    for (final c in _connections) {
      if (c.isRunning) activeServers++;
      totalClients += c.clientCount;
      totalRx += c.rxCount;
      totalTx += c.txCount;
      totalGoose += c.manager.gooseService.items.length;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        // Requirement 3: App header icon uses assets image icon
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/icons/iec61850_server_app_512.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icons/iec61850_server_app_512.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
        flexibleSpace: WindowManagerHelper.isSupportedPlatform
            ? const DragToMoveArea(child: SizedBox.expand())
            : null,
        title: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: SizedBox(
                  height: 48,
                  child: _buildTitleRow(context, isDark, i18n),
                ),
              )
            : _buildTitleRow(context, isDark, i18n),
        actions: [
          // Multi-Connection Metrics (Requirement 1)
          _statusBadge(
            label: activeServers > 0
                ? '$activeServers/${_connections.length} ${i18n.t('serversRunning')}'
                : i18n.t('allServersStopped'),
            color: activeServers > 0 ? Colors.green : Colors.grey,
            icon: activeServers > 0 ? Icons.check_circle : Icons.stop_circle,
          ),
          const SizedBox(width: 6),
          _metricChip(icon: Icons.people, label: '${i18n.t('clients')}: $totalClients'),
          const SizedBox(width: 4),
          _metricChip(icon: Icons.swap_vert, label: 'RX: $totalRx | TX: $totalTx'),
          const SizedBox(width: 4),
          _metricChip(icon: Icons.send, label: 'GOOSE: $totalGoose'),
          const SizedBox(width: 6),

          // Start All / Stop All Quick Toggle (Requirement 1)
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.play_circle_fill, color: Colors.green),
            tooltip: i18n.t('startAll'),
            onPressed: () async {
              await Iec61850ServerManager.startAll(_connections);
              setState(() {});
            },
          ),
          IconButton(
            iconSize: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            tooltip: i18n.t('stopAll'),
            onPressed: () async {
              await Iec61850ServerManager.stopAll(_connections);
              setState(() {});
            },
          ),
          const SizedBox(width: 4),

          // Add Connection Button (Requirement 1)
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: i18n.t('newConn'),
            onPressed: _openAddServerDialog,
          ),

          // Edit Current Connection Button
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.tune),
            tooltip: i18n.t('editConn'),
            onPressed: () => _openEditServerDialog(currentConnection),
          ),

          // Save Workspace Button
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.save_outlined),
            tooltip: i18n.t('saveWorkspace'),
            onPressed: _saveWorkspace,
          ),

          // Theme Toggle
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? i18n.t('themeLight') : i18n.t('themeDark'),
            onPressed: widget.onToggleTheme,
          ),

          // Language Picker
          LanguagePickerButton(
            onLanguageChanged: () {
              setState(() {});
              widget.onLanguageChanged?.call();
            },
          ),
          const SizedBox(width: 4),

          // Window Controls (Minimize, Maximize, Close)
          WindowControls(brightness: Theme.of(context).brightness),
        ],
      ),
      body: Row(
        children: [
          // Requirement 2: Left menu fixed max width 88, overflowing text wraps, top icon removed
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
            child: NavigationRail(
              minWidth: 72,
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              // Note: No leading icon above menu destinations!
              destinations: [
                _buildRailDestination(
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree,
                  labelText: i18n.t('tabModel'),
                ),
                _buildRailDestination(
                  icon: Icons.speed_outlined,
                  selectedIcon: Icons.speed,
                  labelText: i18n.t('tabMonitor'),
                ),
                _buildRailDestination(
                  icon: Icons.notifications_none,
                  selectedIcon: Icons.notifications_active,
                  labelText: i18n.t('tabReports'),
                ),
                _buildRailDestination(
                  icon: Icons.send_outlined,
                  selectedIcon: Icons.send,
                  labelText: i18n.t('tabGoose'),
                ),
                _buildRailDestination(
                  icon: Icons.folder_outlined,
                  selectedIcon: Icons.folder_shared,
                  labelText: i18n.t('tabFiles'),
                ),
                _buildRailDestination(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  labelText: i18n.t('tabTraffic'),
                ),
                _buildRailDestination(
                  icon: Icons.menu_book_outlined,
                  selectedIcon: Icons.menu_book,
                  labelText: i18n.t('tabScl'),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main Tab View
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                ModelExplorerTab(
                  manager: currentManager,
                  onDataChanged: () => setState(() {}),
                ),
                DataMonitorTab(
                  manager: currentManager,
                  connections: _connections,
                  activeConnection: currentConnection,
                  onConnectionChanged: (c) {
                    setState(() {
                      _activeConnection = c;
                    });
                  },
                  onDataChanged: () => setState(() {}),
                ),
                ReportsTab(
                  manager: currentManager,
                  onDataChanged: () => setState(() {}),
                ),
                GooseTab(
                  manager: currentManager,
                  onDataChanged: () => setState(() {}),
                ),
                FilesAndSettingsTab(
                  manager: currentManager,
                  onDataChanged: () => setState(() {}),
                ),
                const TrafficTab(),
                SclToolsTab(
                  manager: currentManager,
                  onDataChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
      // Bottom Status Bar
      bottomNavigationBar: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isDark ? Colors.grey[950] : Colors.grey[200],
        child: Row(
          children: [
            Icon(
              currentConnection.isRunning ? Icons.fiber_manual_record : Icons.pause_circle_outline,
              size: 12,
              color: currentConnection.isRunning ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              currentConnection.statusMessage ?? (currentConnection.isRunning ? i18n.t('serverReady') : i18n.t('serverStopped')),
              style: const TextStyle(fontSize: 11),
            ),
            const Spacer(),
            Text(
              '${currentConnection.displayName} (${currentConnection.ip}:${currentConnection.port}) | ${i18n.t("modelLabel")}: ${currentManager.engine.scl?.iedName ?? i18n.t("unloaded")} | ${i18n.t("totalVarsCount")}: ${currentManager.engine.allVariables.length}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Text(
              _now.toIso8601String().substring(11, 19),
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _metricChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.blueGrey),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, bool isDark, AppI18n i18n) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            i18n.t('appTitle'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'v1.0.0',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
