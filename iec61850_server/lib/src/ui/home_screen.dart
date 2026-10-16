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
import 'widgets/iec61850_server_icon.dart';
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
  late final ServerConfig _config;
  late final Iec61850ServerManager _manager;

  int _selectedTabIndex = 0;
  Timer? _uiRefreshTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _config = ServerConfig(
      name: 'IEC 61850 MMS Server',
      ip: '0.0.0.0',
      port: 102,
    );
    _manager = Iec61850ServerManager(config: _config);

    _manager.addListener(() {
      if (mounted) setState(() {});
    });

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

  Future<void> _initAsync() async {
    // 1. Load dictionary
    await DictionaryService.instance.load();

    // 2. Load workspace storage if available
    final savedWorkspace = await WorkspaceStorage.loadWorkspace();
    _config.name = savedWorkspace.config.name;
    _config.ip = savedWorkspace.config.ip;
    _config.port = savedWorkspace.config.port;
    _config.fileTransferDirectory = savedWorkspace.config.fileTransferDirectory;

    // 3. Load default ICD template (server_example_basic_io.icd)
    try {
      final f = File('assets/examples/server_example_basic_io.icd');
      if (f.existsSync()) {
        final parseRes = SclParser.parse(f.readAsStringSync());
        _manager.loadScl(parseRes);
      } else if (mounted) {
        final defaultIcd = await DefaultAssetBundle.of(context).loadString('assets/examples/server_example_basic_io.icd');
        final parseRes = SclParser.parse(defaultIcd);
        _manager.loadScl(parseRes);
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _uiRefreshTimer?.cancel();
    _manager.stopServer();
    super.dispose();
  }

  void _toggleServer() async {
    if (_config.isRunning) {
      _manager.stopServer();
    } else {
      final ok = await _manager.startServer();
      if (!ok && _config.port == 102) {
        // Show dialog asking to switch to port 10102 for non-root
        _showPortSwitchDialog();
      }
    }
  }

  void _showPortSwitchDialog() {
    final i18n = AppI18n.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.amber),
            const SizedBox(width: 8),
            Text(i18n.t('port102WarnTitle')),
          ],
        ),
        content: Text(
          i18n.t('port102WarnMsg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(i18n.t('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              _config.port = 10102;
              await _manager.startServer();
            },
            child: Text(i18n.t('switchTo10102')),
          ),
        ],
      ),
    );
  }

  void _openEditServerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EditServerDialog(
        config: _config,
        onSaved: (newCfg) {
          setState(() {});
          if (_config.isRunning) {
            _manager.restartServer();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final i18n = AppI18n.instance;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Iec61850ServerIcon(
                    size: 26,
                    color: Color(0xFF06B6D4),
                    accentColor: Color(0xFFF59E0B),
                  ),
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Iec61850ServerIcon(
                  size: 26,
                  color: Color(0xFF06B6D4),
                  accentColor: Color(0xFFF59E0B),
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
          // Status Metrics Badges
          _statusBadge(
            label: _config.isRunning ? i18n.t('serverRunning') : i18n.t('serverStopped'),
            color: _config.isRunning ? Colors.green : Colors.red,
            icon: _config.isRunning ? Icons.check_circle : Icons.stop_circle,
          ),
          const SizedBox(width: 8),
          _metricChip(icon: Icons.people, label: '${i18n.t('clients')}: ${_manager.clientCount}'),
          const SizedBox(width: 6),
          _metricChip(icon: Icons.swap_vert, label: 'RX: ${_config.rxCount} | TX: ${_config.txCount}'),
          const SizedBox(width: 6),
          _metricChip(icon: Icons.send, label: 'GOOSE: ${_manager.gooseService.items.length}'),
          const SizedBox(width: 8),
          // Theme Toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? i18n.t('themeLight') : i18n.t('themeDark'),
            onPressed: widget.onToggleTheme,
          ),
          LanguagePickerButton(
            onLanguageChanged: () {
              setState(() {});
              widget.onLanguageChanged?.call();
            },
          ),
          const SizedBox(width: 4),
          WindowControls(brightness: Theme.of(context).brightness),
        ],
      ),
      body: Row(
        children: [
          // Industrial Left Navigation Rail
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedTabIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 8),
                IconButton.filled(
                  iconSize: 28,
                  style: IconButton.styleFrom(
                    backgroundColor: _config.isRunning ? Colors.green[700] : Colors.red[700],
                  ),
                  icon: Icon(_config.isRunning ? Icons.power_settings_new : Icons.play_arrow),
                  tooltip: _config.isRunning ? i18n.t('stopServer') : i18n.t('startServer'),
                  onPressed: _toggleServer,
                ),
                const SizedBox(height: 4),
                Text(
                  _config.isRunning ? 'RUNNING' : 'STOPPED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _config.isRunning ? Colors.green : Colors.red,
                  ),
                ),
                const Divider(height: 24, thickness: 1),
              ],
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.account_tree_outlined),
                selectedIcon: const Icon(Icons.account_tree),
                label: Text(i18n.t('tabModel')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.speed_outlined),
                selectedIcon: const Icon(Icons.speed),
                label: Text(i18n.t('tabMonitor')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.notifications_none),
                selectedIcon: const Icon(Icons.notifications_active),
                label: Text(i18n.t('tabReports')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.send_outlined),
                selectedIcon: const Icon(Icons.send),
                label: Text(i18n.t('tabGoose')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.folder_outlined),
                selectedIcon: const Icon(Icons.folder_shared),
                label: Text(i18n.t('tabFiles')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
                label: Text(i18n.t('tabTraffic')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: Text(i18n.t('tabScl')),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main Tab View
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
      // Bottom Status Bar
      bottomNavigationBar: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: isDark ? Colors.grey[950] : Colors.grey[200],
        child: Row(
          children: [
            Icon(
              _config.isRunning ? Icons.fiber_manual_record : Icons.pause_circle_outline,
              size: 12,
              color: _config.isRunning ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 6),
            Text(
              _config.statusMessage ?? (_config.isRunning ? i18n.t('serverReady') : i18n.t('serverStopped')),
              style: const TextStyle(fontSize: 11),
            ),
            const Spacer(),
            Text(
              '${i18n.t("modelLabel")}: ${_manager.engine.scl?.iedName ?? i18n.t("unloaded")} | ${i18n.t("totalVarsCount")}: ${_manager.engine.allVariables.length}',
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
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'IEC 61850',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Text(i18n.t('appTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 12),
        // Server IP:Port Chip
        ActionChip(
          avatar: const Icon(Icons.settings, size: 16),
          label: Text('${_config.ip}:${_config.port}'),
          onPressed: _openEditServerDialog,
        ),
      ],
    );
  }
}

