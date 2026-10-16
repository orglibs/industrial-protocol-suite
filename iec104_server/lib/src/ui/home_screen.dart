import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import '../server/iec104_server.dart';
import '../server/workspace_storage.dart';
import 'tabs/auto_sim_tab.dart';
import 'tabs/parser_tab.dart';
import 'tabs/server_tab.dart';
import 'tabs/station_tab.dart';
import 'tabs/traffic_tab.dart';
import 'widgets/iec104_slave_icon.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final Iec104Server server;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.server,
    this.onToggleTheme,
    this.isDarkMode = true,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _statusSub;
  StreamSubscription? _stationSub;
  StreamSubscription? _clientSub;

  @override
  void initState() {
    super.initState();
    _statusSub = widget.server.statusStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationSub = widget.server.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
    _clientSub = widget.server.clientsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _stationSub?.cancel();
    _clientSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning = widget.server.isRunning;

    int totalPoints = 0;
    int autoSimCount = 0;
    for (final s in widget.server.stations.values) {
      totalPoints += s.points.length;
      autoSimCount += s.points.values.where((p) => p.autoChangeEnabled).length;
    }

    final i18n = AppI18n.instance;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Iec104SlaveIcon(size: 26, color: Color(0xFF10B981)),
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Iec104SlaveIcon(size: 26, color: Color(0xFF10B981)),
              ),
        flexibleSpace: WindowManagerHelper.isSupportedPlatform
            ? const DragToMoveArea(child: SizedBox.expand())
            : null,
        title: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: SizedBox(
                  height: 48,
                  child: _buildTitleRow(theme, i18n),
                ),
              )
            : _buildTitleRow(theme, i18n),
        actions: [
          // Quick Start / Stop Toggle
          FilledButton.tonalIcon(
            icon: Icon(
              isRunning ? Icons.stop : Icons.play_arrow,
              size: 16,
              color: isRunning ? Colors.red : Colors.green,
            ),
            label: Text(isRunning ? i18n.t('stopListen') : i18n.t('startListen')),
            onPressed: () async {
              if (isRunning) {
                await widget.server.stop();
              } else {
                try {
                  await widget.server.start();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${AppI18n.instance.t('startListen')} failed: $e')),
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
            tooltip: i18n.t('saveWorkspace'),
            onPressed: () async {
              final ok = await widget.server.saveWorkspace();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '${AppI18n.instance.t('saveWorkspace')} -> ${WorkspaceStorage.getWorkspaceFilePath()}'
                        : '${AppI18n.instance.t('save')} failed'),
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

          WindowControls(brightness: theme.brightness),
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
              child: Icon(Icons.device_hub, size: 28),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.settings_ethernet_outlined),
                selectedIcon: const Icon(Icons.settings_ethernet),
                label: Text(i18n.t('tabServer')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.view_list_outlined),
                selectedIcon: const Icon(Icons.view_list),
                label: Text(i18n.t('tabPoints')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.swap_horiz_outlined),
                selectedIcon: const Icon(Icons.swap_horiz),
                label: Text(i18n.t('tabTraffic')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.terminal_outlined),
                selectedIcon: const Icon(Icons.terminal),
                label: Text(i18n.t('tabParser')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.show_chart_outlined),
                selectedIcon: const Icon(Icons.show_chart),
                label: Text(i18n.t('tabAutoSim')),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          // Tab Content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ServerTab(server: widget.server),
                StationTab(server: widget.server),
                const TrafficTab(),
                const ParserTab(),
                AutoSimTab(server: widget.server),
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
                color: isRunning ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                isRunning ? '${AppI18n.instance.t('serversRunning')} (Port: ${widget.server.port})' : AppI18n.instance.t('allServersStopped'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('${AppI18n.instance.t('connectedMasters')}: ${widget.server.clients.length}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${AppI18n.instance.t('coa')}: ${widget.server.stations.length}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${AppI18n.instance.t('pointsCount')}: $totalPoints', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              if (autoSimCount > 0) ...[
                const Icon(Icons.waves, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('$autoSimCount ${AppI18n.instance.t('simRunningStatus')}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                const SizedBox(width: 20),
              ],
              Text(AppI18n.instance.t('footerNote'), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
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
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }
}
