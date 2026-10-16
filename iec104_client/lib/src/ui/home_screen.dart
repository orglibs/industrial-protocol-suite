import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../client/iec104_client.dart';
import '../client/traffic_logger.dart';
import '../client/workspace_storage.dart';
import '../i18n/app_i18n.dart';
import 'tabs/connection_tab.dart';
import 'tabs/points_tab.dart';
import 'tabs/commands_tab.dart';
import 'tabs/traffic_tab.dart';
import 'tabs/parser_tab.dart';
import 'widgets/iec104_master_icon.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final Iec104Client client;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    required this.client,
    this.onToggleTheme,
    this.isDarkMode = true,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final StreamSubscription<ClientConnectionState> _stateSub;
  StreamSubscription? _stationsSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationsSub = widget.client.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _stationsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.client;

    Color badgeColor = Colors.grey;
    if (c.state == ClientConnectionState.connecting) badgeColor = Colors.orange;
    if (c.state == ClientConnectionState.connected) badgeColor = Colors.blue;
    if (c.state == ClientConnectionState.active) badgeColor = Colors.green;

    int totalPoints = 0;
    for (final s in c.stations.values) {
      totalPoints += s.points.length;
    }

    final allTraffic = TrafficLogger.instance.entries;
    final rxCount = allTraffic.where((e) => e.direction == TrafficDirection.rx).length;
    final txCount = allTraffic.where((e) => e.direction == TrafficDirection.tx).length;

    final tabs = [
      ConnectionTab(client: c),
      PointsTab(client: c),
      CommandsTab(client: c),
      const TrafficTab(),
      const ParserTab(),
    ];

    final isConnected = c.state == ClientConnectionState.connected || c.state == ClientConnectionState.active;

    final i18n = AppI18n.instance;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Iec104MasterIcon(size: 26, color: Color(0xFF10B981)),
                ),
              )
            : const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Iec104MasterIcon(size: 26, color: Color(0xFF10B981)),
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
          // Connection Status indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: badgeColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getStateLabel(c.state, i18n),
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
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
            label: Text(isConnected ? i18n.t('disconnect') : i18n.t('connect')),
            onPressed: () async {
              if (isConnected) {
                await c.disconnect();
              } else {
                try {
                  await c.connect();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${i18n.t('connectFailed')}: $e')),
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
              final ok = await c.saveWorkspace();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? '${i18n.t('workspaceSaved')}: ${WorkspaceStorage.getWorkspaceFilePath()}'
                        : i18n.t('saveFailed')),
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
            selectedIndex: _currentIndex,
            onDestinationSelected: (val) => setState(() => _currentIndex = val),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Icon(Icons.device_hub, size: 28),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.settings_ethernet_outlined),
                selectedIcon: const Icon(Icons.settings_ethernet),
                label: Text(i18n.t('tabConnection')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.table_chart_outlined),
                selectedIcon: const Icon(Icons.table_chart),
                label: Text(i18n.t('tabPoints')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.send_outlined),
                selectedIcon: const Icon(Icons.send),
                label: Text(i18n.t('tabCommands')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long),
                label: Text(i18n.t('tabTraffic')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.code_outlined),
                selectedIcon: const Icon(Icons.code),
                label: Text(i18n.t('tabParser')),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: tabs,
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
              Text(
                c.state == ClientConnectionState.active
                    ? '${i18n.t('linkActive')} (${c.host}:${c.port})'
                    : (c.state == ClientConnectionState.connected ? i18n.t('tcpConnected') : i18n.t('clientDisconnected')),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('${i18n.t('coaStation')}: ${c.stations.length}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${i18n.t('totalPoints')}: $totalPoints', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('RX: $rxCount ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Text('TX: $txCount ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text(i18n.t('iec104MasterSim'), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
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

  String _getStateLabel(ClientConnectionState state, AppI18n i18n) {
    switch (state) {
      case ClientConnectionState.disconnected:
        return i18n.t('disconnected');
      case ClientConnectionState.connecting:
        return i18n.t('connecting');
      case ClientConnectionState.connected:
        return i18n.t('connected');
      case ClientConnectionState.active:
        return i18n.t('stateActive');
    }
  }
}
