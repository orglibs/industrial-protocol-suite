import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../client/iec104_client.dart';
import '../client/traffic_logger.dart';
import '../client/workspace_storage.dart';
import '../i18n/app_i18n.dart';
import '../models/connection_config.dart';
import 'dialogs/edit_connection_dialog.dart';
import 'tabs/connection_tab.dart';
import 'tabs/points_tab.dart';
import 'tabs/commands_tab.dart';
import 'tabs/traffic_tab.dart';
import 'tabs/parser_tab.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final List<Iec104ClientConnectionConfig>? initialConnections;
  final Iec104Client? client;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    this.initialConnections,
    this.client,
    this.onToggleTheme,
    this.isDarkMode = true,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Iec104ClientConnectionConfig> _connections;
  late Iec104ClientConnectionConfig _activeConnection;

  StreamSubscription<ClientConnectionState>? _stateSub;
  StreamSubscription? _stationsSub;

  Iec104Client get _activeClient => _activeConnection.client;

  @override
  void initState() {
    super.initState();
    _initConnections();
    _subscribeActiveClient();
  }

  void _initConnections() {
    if (widget.initialConnections != null && widget.initialConnections!.isNotEmpty) {
      _connections = widget.initialConnections!;
    } else if (widget.client != null) {
      _connections = [
        Iec104ClientConnectionConfig(
          id: 'client-conn-default',
          name: 'IEC 104 TCP Client',
          nameKey: 'preset_conn_iec104_default',
          host: widget.client!.host,
          port: widget.client!.port,
          client: widget.client!,
        ),
      ];
    } else {
      _connections = Iec104ClientConnectionConfig.createDefaultConnections();
    }
    _activeConnection = _connections.first;
  }

  void _subscribeActiveClient() {
    _stateSub?.cancel();
    _stationsSub?.cancel();

    _stateSub = _activeClient.stateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _stationsSub = _activeClient.stationsStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _switchActiveConnection(Iec104ClientConnectionConfig newConn) async {
    setState(() {
      _activeConnection = newConn;
    });
    _subscribeActiveClient();
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
          SnackBar(content: Text('${AppI18n.instance.t('newConn')}: ${newConn.displayName}')),
        );
      }
    }
  }

  Future<void> _onDeleteConnection(Iec104ClientConnectionConfig conn) async {
    final i18n = AppI18n.instance;
    if (_connections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.t('deleteConn'))),
      );
      return;
    }

    if (conn.isConnected) {
      await conn.client.disconnect();
    }

    setState(() {
      _connections.remove(conn);
      if (_activeConnection == conn) {
        _activeConnection = _connections.first;
      }
    });

    _subscribeActiveClient();
    await _saveWorkspace();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${i18n.t('deleteConn')}: ${conn.displayName}')),
      );
    }
  }

  Future<void> _saveWorkspace() async {
    final i18n = AppI18n.instance;
    final ok = await WorkspaceStorage.saveConnections(_connections);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '${i18n.t('workspaceSaved')}: ${WorkspaceStorage.getWorkspaceFilePath()}'
              : i18n.t('saveFailed')),
          backgroundColor: ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onConfigChanged() {
    _activeConnection.syncConfigFromClient();
    WorkspaceStorage.saveConnections(_connections);
    setState(() {});
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _stationsSub?.cancel();
    super.dispose();
  }

  Widget _buildHeaderIcon() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/icons/iec104_master_app_512.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final c = _activeClient;
    final isConnected = c.state == ClientConnectionState.connected || c.state == ClientConnectionState.active;

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
      ConnectionTab(
        connections: _connections,
        activeConnection: _activeConnection,
        onSelectConnection: _switchActiveConnection,
        onConfigChanged: _onConfigChanged,
        onAddConnection: _onAddConnection,
        onDeleteConnection: _onDeleteConnection,
        client: _activeClient,
      ),
      PointsTab(
        connections: _connections,
        activeConnection: _activeConnection,
        onSelectConnection: _switchActiveConnection,
        onConfigChanged: _onConfigChanged,
        client: _activeClient,
      ),
      CommandsTab(
        connections: _connections,
        activeConnection: _activeConnection,
        onSelectConnection: _switchActiveConnection,
        client: _activeClient,
      ),
      const TrafficTab(),
      const ParserTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(child: _buildHeaderIcon())
            : _buildHeaderIcon(),
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
            onPressed: _saveWorkspace,
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
          // Requirement 2: Left menu fixed max width (maxWidth: 88), wrap overflowing text, no top leading icon
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 88),
            child: NavigationRail(
              minWidth: 72,
              selectedIndex: _currentIndex,
              onDestinationSelected: (val) => setState(() => _currentIndex = val),
              labelType: NavigationRailLabelType.all,
              destinations: [
                _buildRailDestination(
                  icon: Icons.settings_ethernet_outlined,
                  selectedIcon: Icons.settings_ethernet,
                  labelText: i18n.t('tabConnection'),
                ),
                _buildRailDestination(
                  icon: Icons.table_chart_outlined,
                  selectedIcon: Icons.table_chart,
                  labelText: i18n.t('tabPoints'),
                ),
                _buildRailDestination(
                  icon: Icons.send_outlined,
                  selectedIcon: Icons.send,
                  labelText: i18n.t('tabCommands'),
                ),
                _buildRailDestination(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  labelText: i18n.t('tabTraffic'),
                ),
                _buildRailDestination(
                  icon: Icons.code_outlined,
                  selectedIcon: Icons.code,
                  labelText: i18n.t('tabParser'),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              key: ValueKey('${_activeConnection.id}_${i18n.currentLanguage.code}'),
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
                    : (c.state == ClientConnectionState.connected
                        ? i18n.t('tcpConnected')
                        : i18n.t('clientDisconnected')),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text('${i18n.t('coaStation')}: ${c.stations.length}',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${i18n.t('totalPoints')}: $totalPoints',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('RX: $rxCount ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Text('TX: $txCount ${i18n.t('frames')}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text(i18n.t('iec104MasterSim'),
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(ThemeData theme, AppI18n i18n) {
    return ClipRect(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              i18n.t('appTitle'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('v1.0.0', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
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
