import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import '../models/connection_config.dart';
import '../models/workspace_storage.dart';
import '../protocol/modbus_server.dart';
import '../services/simulation_service.dart';
import 'tabs/chart_tab.dart';
import 'tabs/register_view_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/topology_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final List<ConnectionConfig> initialConnections;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.initialConnections,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.onLanguageChanged,
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
        SnackBar(content: Text(AppI18n.instance.t('saveWorkspace'))),
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
    final isSimRunning = SimulationService.instance.isRunning;
    final i18n = AppI18n.instance;

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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: AppBar(
          toolbarHeight: 46,
          titleSpacing: 0,
          leading: WindowManagerHelper.isSupportedPlatform
              ? DragToMoveArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/icons/modbus_slave_app_512.png',
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
                      'assets/icons/modbus_slave_app_512.png',
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            i18n.t('appTitle'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                )
              : SizedBox(
                  height: 46,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          i18n.t('appTitle'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
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
                  ),
                ),
          actions: [
            // Start All
            IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.play_circle_fill, color: Colors.green),
              tooltip: i18n.t('startAll'),
              onPressed: () async {
                await ModbusServerManager.instance.startAll(_connections);
                setState(() {});
              },
            ),
            // Stop All
            IconButton(
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.stop_circle, color: Colors.red),
              tooltip: i18n.t('stopAll'),
              onPressed: () async {
                await ModbusServerManager.instance.stopAll(_connections);
                setState(() {});
              },
            ),
            // Save Workspace
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
            // Window Controls (Minimize, Maximize, Close)
            WindowControls(brightness: theme.brightness),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left NavigationRail
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
            child: NavigationRail(
              minWidth: 72,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              labelType: NavigationRailLabelType.all,
              destinations: [
                _buildRailDestination(
                  icon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view,
                  labelText: i18n.t('tabRegisters'),
                ),
                _buildRailDestination(
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree,
                  labelText: i18n.t('tabConnections'),
                ),
                _buildRailDestination(
                  icon: Icons.sync_alt_outlined,
                  selectedIcon: Icons.sync_alt,
                  labelText: i18n.t('tabTraffic'),
                ),
                _buildRailDestination(
                  icon: Icons.show_chart_outlined,
                  selectedIcon: Icons.show_chart,
                  labelText: i18n.t('tabCharts'),
                ),
                _buildRailDestination(
                  icon: Icons.construction_outlined,
                  selectedIcon: Icons.construction,
                  labelText: i18n.t('tabTools'),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: activeServers > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                activeServers > 0
                    ? '${i18n.t('serversRunning')} ($activeServers)'
                    : i18n.t('allServersStopped'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('${i18n.t('connectedMasters')}: $totalClients', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${i18n.t('rxReceived')}: $totalRx ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Text('${i18n.t('txSent')}: $totalTx ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              if (isSimRunning) ...[
                const SizedBox(width: 20),
                const Icon(Icons.waves, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(i18n.t('simRunningStatus'), style: const TextStyle(fontSize: 12, color: Colors.green)),
              ],
              const SizedBox(width: 24),
              Text(i18n.t('footerNote'), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
