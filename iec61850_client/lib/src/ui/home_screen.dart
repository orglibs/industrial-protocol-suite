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
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import 'widgets/iec61850_client_icon.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.onLanguageChanged,
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
        name: 'Local Test Server (127.0.0.1:102)',
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
              conn.statusMessage ?? '${AppI18n.instance.t("connectFailed")}: ${conn.port}',
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
        title: Text(AppI18n.instance.t('confirmDeleteConn')),
        content: Text('${AppI18n.instance.t("confirmDeleteConn")}: "${conn.name}" (${conn.ip}:${conn.port})?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppI18n.instance.t('cancel'))),
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
            child: Text(AppI18n.instance.t('delete')),
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

    final i18n = AppI18n.instance;

    return Scaffold(
      body: Column(
        children: [
          // 1. Top Industrial Connection & Status Bar
          Container(
            height: 60,
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8ECEF),
              border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Stack(
              children: [
                if (WindowManagerHelper.isSupportedPlatform)
                  const Positioned.fill(
                    child: DragToMoveArea(child: SizedBox.expand()),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1150;
                    final showSubtitle = constraints.maxWidth >= 950;

                    final logoAndTitle = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Iec61850ClientIcon(size: 28, color: Color(0xFF0284C7), accentColor: Color(0xFF818CF8)),
                        const SizedBox(width: 10),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i18n.t('appTitle'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                            ),
                            if (showSubtitle)
                              Text(
                                i18n.t('appSubTitle'),
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      ],
                    );

                    return Row(
                      children: [
                        // App Logo & Title
                        WindowManagerHelper.isSupportedPlatform
                            ? DragToMoveArea(child: logoAndTitle)
                            : logoAndTitle,
                        const SizedBox(width: 12),

                        // Connection Dropdown Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: isWide ? 180 : 130),
                                      child: Text(
                                        '${c.name} (${c.ip}:${c.port})',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
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
                        const SizedBox(width: 4),

                        // Add Connection Button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                          tooltip: i18n.t('newConn'),
                          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: () => _openCreateConnectionDialog(),
                        ),
                        // Edit Connection Button
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: i18n.t('editConn'),
                          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: conn != null ? () => _openCreateConnectionDialog(editConfig: conn) : null,
                        ),
                        // Delete Connection Button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          tooltip: i18n.t('deleteConn'),
                          constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                          padding: EdgeInsets.zero,
                          onPressed: _manager.connections.length > 1 ? _deleteCurrentConnection : null,
                        ),

                        const SizedBox(width: 8),

                        // Connect / Disconnect Action Button
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isConn ? Colors.red[700] : Colors.green[700],
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(isConn ? Icons.power_settings_new : Icons.play_arrow, size: 18),
                          label: Text(
                            isConn ? i18n.t('disconnect') : i18n.t('connect'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          onPressed: _isConnecting ? null : _toggleConnection,
                        ),

                        // Draggable Area
                        Expanded(
                          child: WindowManagerHelper.isSupportedPlatform
                              ? const DragToMoveArea(child: SizedBox(height: 60))
                              : const SizedBox(height: 60),
                        ),

                        // Theme Toggle Button
                        IconButton(
                          icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
                          tooltip: widget.isDarkMode ? i18n.t('themeLight') : i18n.t('themeDark'),
                          constraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: widget.onToggleTheme,
                        ),

                        // LanguagePickerButton
                        LanguagePickerButton(
                          onLanguageChanged: () {
                            setState(() {});
                            widget.onLanguageChanged?.call();
                          },
                        ),
                        const SizedBox(width: 4),

                        // WindowControls
                        WindowControls(brightness: Theme.of(context).brightness),
                      ],
                    );
                  },
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
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.account_tree_outlined),
                      selectedIcon: const Icon(Icons.account_tree),
                      label: Text(i18n.t('tabModel'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.grid_view_outlined),
                      selectedIcon: const Icon(Icons.grid_view),
                      label: Text(i18n.t('tabMonitor'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.mark_email_unread_outlined),
                      selectedIcon: const Icon(Icons.mark_email_unread),
                      label: Text(i18n.t('tabReports'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.radar_outlined),
                      selectedIcon: const Icon(Icons.radar),
                      label: Text(i18n.t('tabGoose'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.folder_shared_outlined),
                      selectedIcon: const Icon(Icons.folder_shared),
                      label: Text(i18n.t('tabFiles'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.troubleshoot_outlined),
                      selectedIcon: const Icon(Icons.troubleshoot),
                      label: Text(i18n.t('tabTraffic'), style: const TextStyle(fontSize: 11)),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.library_books_outlined),
                      selectedIcon: const Icon(Icons.library_books),
                      label: Text(i18n.t('tabScl'), style: const TextStyle(fontSize: 11)),
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                        ? '${conn.name} (${conn.ip}:${conn.port}) - ${conn.statusMessage ?? (isConn ? i18n.t("connectedStatus") : i18n.t("disconnectedStatus"))}'
                        : i18n.t('noConnSelected'),
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusChip(
                    label: 'TX',
                    value: '${conn?.txCount ?? 0}',
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(
                    label: 'RX',
                    value: '${conn?.rxCount ?? 0}',
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(
                    label: i18n.t('points'),
                    value: '${engine?.allVariables.length ?? 0}',
                    color: Colors.purpleAccent,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${i18n.t("colPoll")}: ${engine?.allVariables.where((v) => v.isPolling).length ?? 0}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'v1.0.0',
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
