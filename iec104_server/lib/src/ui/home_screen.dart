import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import '../models/connection_config.dart';
import '../server/iec104_server.dart';
import '../server/workspace_storage.dart';
import 'tabs/auto_sim_tab.dart';
import 'tabs/parser_tab.dart';
import 'tabs/server_tab.dart';
import 'tabs/station_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final List<Iec104ConnectionConfig>? initialConnections;
  final Iec104Server? server;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    this.initialConnections,
    this.server,
    this.onToggleTheme,
    this.isDarkMode = true,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Iec104ConnectionConfig> _connections;

  @override
  void initState() {
    super.initState();
    _initConnections();
    _listenToConnections();
  }

  void _initConnections() {
    if (widget.initialConnections != null && widget.initialConnections!.isNotEmpty) {
      _connections = widget.initialConnections!;
    } else if (widget.server != null) {
      _connections = [
        Iec104ConnectionConfig(
          id: 'conn-server',
          name: 'IEC 104 Server',
          host: widget.server!.host,
          port: widget.server!.port,
          server: widget.server!,
        ),
      ];
    } else {
      _connections = Iec104ServerManager.createDefaultPresets();
    }
  }

  void _listenToConnections() {
    for (final c in _connections) {
      c.server.statusStream.listen((_) {
        if (mounted) setState(() {});
      });
      c.server.clientsStream.listen((_) {
        if (mounted) setState(() {});
      });
      c.server.stationsStream.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _saveWorkspace() async {
    await WorkspaceStorage.saveConnections(_connections);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppI18n.instance.t('saveWorkspace')} -> ${WorkspaceStorage.getWorkspaceFilePath()}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;

    int activeServers = 0;
    int totalClients = 0;
    int totalStations = 0;
    int totalPoints = 0;
    int autoSimCount = 0;
    int totalRx = 0;
    int totalTx = 0;

    for (final c in _connections) {
      if (c.isRunning) activeServers++;
      totalClients += c.clientCount;
      totalStations += c.stations.length;
      totalRx += c.server.rxCount;
      totalTx += c.server.txCount;
      for (final s in c.stations) {
        totalPoints += s.points.length;
        autoSimCount += s.points.values.where((p) => p.autoChangeEnabled).length;
      }
    }

    final isAnyRunning = activeServers > 0;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: AppBar(
          toolbarHeight: 46,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          // Requirement 3: App header icon uses assets icon
          leading: WindowManagerHelper.isSupportedPlatform
              ? DragToMoveArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/icons/iec104_slave_app_512.png',
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
                      'assets/icons/iec104_slave_app_512.png',
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
                    height: 46,
                    child: _buildTitleRow(theme, i18n),
                  ),
                )
              : SizedBox(
                  height: 46,
                  child: _buildTitleRow(theme, i18n),
                ),
          actions: [
            // Start All / Stop All Quick Toggle (Requirement 1: Multi-connection management)
            IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
              tooltip: i18n.t('startAll'),
              onPressed: () async {
                await Iec104ServerManager.instance.startAll(_connections);
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
                await Iec104ServerManager.instance.stopAll(_connections);
                setState(() {});
              },
            ),
            const SizedBox(width: 4),

            // Save Workspace Button
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.save_outlined),
              tooltip: i18n.t('saveWorkspace'),
              onPressed: _saveWorkspace,
            ),

            // Theme Toggle Button
            if (widget.onToggleTheme != null)
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

            // Window Controls (Minimize, Maximize, Close)
            WindowControls(brightness: theme.brightness),
          ],
        ),
      ),
      body: Row(
        children: [
          // Requirement 2: Left menu fixed max width, overflowing text wraps, top icon removed
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
            child: NavigationRail(
              minWidth: 72,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              labelType: NavigationRailLabelType.all,
              // Note: No leading icon!
              destinations: [
                _buildRailDestination(
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree,
                  labelText: i18n.t('tabServer'),
                ),
                _buildRailDestination(
                  icon: Icons.view_list_outlined,
                  selectedIcon: Icons.view_list,
                  labelText: i18n.t('tabPoints'),
                ),
                _buildRailDestination(
                  icon: Icons.swap_horiz_outlined,
                  selectedIcon: Icons.swap_horiz,
                  labelText: i18n.t('tabTraffic'),
                ),
                _buildRailDestination(
                  icon: Icons.terminal_outlined,
                  selectedIcon: Icons.terminal,
                  labelText: i18n.t('tabParser'),
                ),
                _buildRailDestination(
                  icon: Icons.show_chart_outlined,
                  selectedIcon: Icons.show_chart,
                  labelText: i18n.t('tabAutoSim'),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),

          // Tab Content
          Expanded(
            child: IndexedStack(
              key: ValueKey(i18n.currentLanguage.code),
              index: _selectedIndex,
              children: [
                ServerTab(
                  connections: _connections,
                  onDataChanged: () => setState(() {}),
                ),
                StationTab(
                  connections: _connections,
                  onDataChanged: () => setState(() {}),
                ),
                const TrafficTab(),
                const ParserTab(),
                AutoSimTab(
                  connections: _connections,
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
                color: isAnyRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                isAnyRunning
                    ? '$activeServers/${_connections.length} ${i18n.t('serversRunning')}'
                    : i18n.t('allServersStopped'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('${i18n.t('connectedMasters')}: $totalClients', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${i18n.t('coa')}: $totalStations', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${i18n.t('pointsCount')}: $totalPoints', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('Rx: $totalRx | Tx: $totalTx', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              if (autoSimCount > 0) ...[
                const Icon(Icons.waves, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('$autoSimCount ${i18n.t('simRunningStatus')}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                const SizedBox(width: 20),
              ],
              Text(i18n.t('footerNote'), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(ThemeData theme, AppI18n i18n) {
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
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('v1.0.0', style: TextStyle(fontSize: 10)),
        ),
      ],
    );
  }
}
