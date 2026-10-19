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
    final connsToLoad = ws.connections.isNotEmpty
        ? ws.connections
        : ConnectionConfig.createDefaultConnections();

    for (final conn in connsToLoad) {
      _manager.addConnection(conn);
      await _loadSclForConnection(conn);
    }

    if (mounted) setState(() {});
  }

  Future<void> _loadSclForConnection(ConnectionConfig conn) async {
    if (conn.boundSclPath == null || conn.boundSclPath!.isEmpty) return;
    try {
      final content = _readSclFile(conn.boundSclPath!);
      if (content != null && content.isNotEmpty) {
        final res = SclParser.parseString(content);
        _manager.bindSclToConnection(conn, res, conn.boundSclPath);
      }
    } catch (_) {}
  }

  String? _readSclFile(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) return f.readAsStringSync();
    } catch (_) {}
    final candidate = 'assets/examples/${path.split('/').last}';
    try {
      final f = File(candidate);
      if (f.existsSync()) return f.readAsStringSync();
    } catch (_) {}
    return null;
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
            editConfig.nameKey = cfg.nameKey;
            editConfig.ip = cfg.ip;
            editConfig.port = cfg.port;
            editConfig.localTsap = cfg.localTsap;
            editConfig.remoteTsap = cfg.remoteTsap;
            editConfig.boundSclPath = cfg.boundSclPath;
            editConfig.autoConnect = cfg.autoConnect;
            editConfig.pollIntervalMs = cfg.pollIntervalMs;
            editConfig.notifyUpdated();
            if (cfg.boundSclPath != null && cfg.boundSclPath!.isNotEmpty) {
              _loadSclForConnection(editConfig);
            }
          } else {
            _manager.addConnection(cfg);
            _manager.selectedConnectionId = cfg.id;
            if (cfg.boundSclPath != null && cfg.boundSclPath!.isNotEmpty) {
              _loadSclForConnection(cfg);
            }
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

  void _copyCurrentConnection() {
    final conn = _manager.selectedConnection;
    if (conn == null) return;

    final newId = 'conn_${DateTime.now().millisecondsSinceEpoch}';
    final copiedName = '${conn.displayName} (${AppI18n.instance.t("copyConn")})';
    final newConn = ConnectionConfig(
      id: newId,
      name: copiedName,
      nameKey: null,
      ip: conn.ip,
      port: conn.port,
      localTsap: conn.localTsap,
      remoteTsap: conn.remoteTsap,
      boundSclPath: conn.boundSclPath,
      autoConnect: false,
      pollIntervalMs: conn.pollIntervalMs,
    );

    _manager.addConnection(newConn);
    _manager.selectedConnectionId = newId;

    if (newConn.boundSclPath != null && newConn.boundSclPath!.isNotEmpty) {
      _loadSclForConnection(newConn);
    }

    ClientWorkspaceStorage.saveWorkspace(
      _manager.connections,
      _manager.activeEngine?.allVariables ?? [],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppI18n.instance.t('copyConnSuccess')),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  void _deleteCurrentConnection() {
    final conn = _manager.selectedConnection;
    if (conn == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppI18n.instance.t('confirmDeleteConn')),
        content: Text('${AppI18n.instance.t("confirmDeleteConn")}: "${conn.displayName}" (${conn.ip}:${conn.port})?'),
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
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isEnabled
                    ? (color?.withValues(alpha: isDark ? 0.35 : 0.25) ?? (isDark ? Colors.grey[700]! : Colors.grey[350]!))
                    : (isDark ? Colors.grey[850]! : Colors.grey[300]!),
                width: 0.8,
              ),
              color: isEnabled
                  ? (color?.withValues(alpha: isDark ? 0.12 : 0.06) ?? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)))
                  : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02)),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 17,
              color: isEnabled
                  ? (color ?? (isDark ? Colors.grey[300] : Colors.grey[750]!))
                  : (isDark ? Colors.grey[600] : Colors.grey[400]),
            ),
          ),
        ),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/icons/iec61850_client_app_512.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
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
                        Tooltip(
                          message: conn != null
                              ? '${conn.displayName} (${conn.ip}:${conn.port})'
                                  '${conn.boundSclPath != null && conn.boundSclPath!.isNotEmpty ? "\nSCL: ${conn.boundSclPath}" : ""}'
                                  '\n${i18n.t(conn.isConnected ? "connectedStatus" : "disconnectedStatus")}'
                              : i18n.t('noConnHint'),
                          waitDuration: const Duration(milliseconds: 200),
                          child: Container(
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
                                final itemTooltip = '${c.displayName} (${c.ip}:${c.port})'
                                    '${c.boundSclPath != null && c.boundSclPath!.isNotEmpty ? "\nSCL: ${c.boundSclPath}" : ""}'
                                    '\n${i18n.t(c.isConnected ? "connectedStatus" : "disconnectedStatus")}';
                                return DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Tooltip(
                                    message: itemTooltip,
                                    waitDuration: const Duration(milliseconds: 200),
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
                                            '${c.displayName} (${c.ip}:${c.port})',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
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
                        ),
                        const SizedBox(width: 8),

                        // Add Connection Button
                        _buildHeaderIconButton(
                          icon: Icons.add_circle_outline,
                          tooltip: i18n.t('newConn'),
                          color: Colors.blueAccent,
                          onPressed: () => _openCreateConnectionDialog(),
                        ),
                        const SizedBox(width: 6),

                        // Copy Connection Button
                        _buildHeaderIconButton(
                          icon: Icons.copy_outlined,
                          tooltip: i18n.t('copyConn'),
                          onPressed: conn != null ? _copyCurrentConnection : null,
                        ),
                        const SizedBox(width: 6),

                        // Edit Connection Button
                        _buildHeaderIconButton(
                          icon: Icons.edit_outlined,
                          tooltip: i18n.t('editConn'),
                          onPressed: conn != null ? () => _openCreateConnectionDialog(editConfig: conn) : null,
                        ),
                        const SizedBox(width: 6),

                        // Delete Connection Button
                        _buildHeaderIconButton(
                          icon: Icons.delete_outline,
                          tooltip: i18n.t('deleteConn'),
                          color: Colors.redAccent,
                          onPressed: _manager.connections.length > 1 ? _deleteCurrentConnection : null,
                        ),

                        const SizedBox(width: 10),

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
                        _buildHeaderIconButton(
                          icon: widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          tooltip: widget.isDarkMode ? i18n.t('themeLight') : i18n.t('themeDark'),
                          color: widget.isDarkMode ? Colors.amber : Colors.blueGrey,
                          onPressed: widget.onToggleTheme,
                        ),
                        const SizedBox(width: 8),

                        // LanguagePickerButton
                        LanguagePickerButton(
                          onLanguageChanged: () {
                            setState(() {});
                            widget.onLanguageChanged?.call();
                          },
                        ),
                        const SizedBox(width: 8),

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
                // Modern Navigation Rail with fixed maxWidth and no top leading icon
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
                  child: NavigationRail(
                    selectedIndex: _selectedTabIndex,
                    labelType: NavigationRailLabelType.all,
                    minWidth: 72,
                    destinations: [
                      _buildRailDestination(
                        icon: Icons.account_tree_outlined,
                        selectedIcon: Icons.account_tree,
                        labelText: i18n.t('tabModel'),
                      ),
                      _buildRailDestination(
                        icon: Icons.grid_view_outlined,
                        selectedIcon: Icons.grid_view,
                        labelText: i18n.t('tabMonitor'),
                      ),
                      _buildRailDestination(
                        icon: Icons.mark_email_unread_outlined,
                        selectedIcon: Icons.mark_email_unread,
                        labelText: i18n.t('tabReports'),
                      ),
                      _buildRailDestination(
                        icon: Icons.radar_outlined,
                        selectedIcon: Icons.radar,
                        labelText: i18n.t('tabGoose'),
                      ),
                      _buildRailDestination(
                        icon: Icons.folder_shared_outlined,
                        selectedIcon: Icons.folder_shared,
                        labelText: i18n.t('tabFiles'),
                      ),
                      _buildRailDestination(
                        icon: Icons.troubleshoot_outlined,
                        selectedIcon: Icons.troubleshoot,
                        labelText: i18n.t('tabTraffic'),
                      ),
                      _buildRailDestination(
                        icon: Icons.library_books_outlined,
                        selectedIcon: Icons.library_books,
                        labelText: i18n.t('tabScl'),
                      ),
                    ],
                    onDestinationSelected: (index) {
                      setState(() => _selectedTabIndex = index);
                    },
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1),

                // Active Tab Content
                Expanded(
                  child: IndexedStack(
                    key: ValueKey(i18n.currentLanguage.code),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
