import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../i18n/app_i18n.dart';
import '../models/connection_config.dart';
import '../models/workspace_storage.dart';
import '../protocol/modbus_client.dart';
import '../services/polling_service.dart';
import 'dialogs/edit_connection_dialog.dart';
import 'dialogs/edit_slave_dialog.dart';
import 'tabs/register_view_tab.dart';
import 'tabs/connection_tab.dart';
import 'tabs/commands_tab.dart';
import 'tabs/traffic_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/chart_tab.dart';
import 'widgets/language_picker.dart';
import 'widgets/window_title_bar.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final VoidCallback? onLanguageChanged;

  const HomeScreen({
    super.key,
    this.onToggleTheme,
    this.isDarkMode = true,
    this.onLanguageChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;

  late List<ConnectionConfig> _connections;
  late ConnectionConfig _activeConfig;
  late ModbusClient _client;
  late PollingService _pollingService;

  @override
  void initState() {
    super.initState();
    _client = ModbusClient();
    _initWorkspace();
  }

  Future<void> _initWorkspace() async {
    _connections = await WorkspaceStorage.loadConnections();
    _activeConfig = _connections.first;
    _pollingService = PollingService(client: _client, config: _activeConfig);
    _pollingService.updateConfig(_activeConfig);

    _client.stateStream.listen((_) {
      if (mounted) setState(() {});
    });

    // If active config is virtual, connect automatically for great first-run experience
    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _switchActiveConnection(ConnectionConfig newConn) async {
    if (_client.state == ModbusConnectionState.connected) {
      _pollingService.stop();
      await _client.disconnect();
    }

    setState(() {
      _activeConfig = newConn;
      _pollingService.updateConfig(_activeConfig);
    });

    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

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

  Future<void> _onDeleteConnection(ConnectionConfig conn) async {
    if (_connections.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('deleteConn'))),
      );
      return;
    }

    if (_client.state == ModbusConnectionState.connected && _activeConfig == conn) {
      _pollingService.stop();
      await _client.disconnect();
    }

    setState(() {
      _connections.remove(conn);
      if (_activeConfig == conn) {
        _activeConfig = _connections.first;
        _pollingService.updateConfig(_activeConfig);
      }
    });

    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      await _client.connect();
      _pollingService.start();
    }

    await _saveWorkspace();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppI18n.instance.t('deleteConn')}: ${conn.displayName}')),
      );
    }
  }

  Future<void> _onAddSlaveToActiveConnection() async {
    final slave = await EditSlaveDialog.show(context);
    if (slave != null) {
      setState(() {
        _activeConfig.slaves.add(slave);
      });
      _onConfigChanged();
    }
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

  void _onConfigChanged() {
    _pollingService.updateConfig(_activeConfig);
    _saveWorkspace();
    setState(() {});
  }

  @override
  void dispose() {
    _pollingService.dispose();
    _client.dispose();
    super.dispose();
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

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(AppI18n.instance.t('waitingInput')),
            ],
          ),
        ),
      );
    }

    final isConnected = _client.state == ModbusConnectionState.connected;
    final i18n = AppI18n.instance;

    // Build connection label for app bar badge
    String peerBadge;
    if (_activeConfig.mode == ModbusTransportMode.virtual) {
      peerBadge = i18n.t('virtualSim');
    } else if (isConnected) {
      if (_activeConfig.mode == ModbusTransportMode.serialRtu) {
        peerBadge = '${i18n.t('connected')}: ${_activeConfig.serialPortName ?? "COM"}';
      } else {
        peerBadge = '${i18n.t('connected')}: ${_activeConfig.ip}:${_activeConfig.port}';
      }
    } else {
      peerBadge = i18n.t('disconnected');
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: WindowManagerHelper.isSupportedPlatform
            ? DragToMoveArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/icons/modbus_master_app_512.png',
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
                    'assets/icons/modbus_master_app_512.png',
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
                  child: _buildTitleRow(theme, i18n),
                ),
              )
            : _buildTitleRow(theme, i18n),
        actions: [
          // Connection Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isConnected ? Colors.green : Colors.grey).withAlpha(38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isConnected ? Colors.green : Colors.grey),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isConnected ? Icons.check_circle : Icons.cancel, size: 14, color: isConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  peerBadge,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isConnected ? Colors.green : Colors.grey),
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
              final messenger = ScaffoldMessenger.of(context);
              if (isConnected) {
                _pollingService.stop();
                await _client.disconnect();
              } else {
                try {
                  await _client.connect();
                  if (_client.state == ModbusConnectionState.connected) {
                    _pollingService.start();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('${AppI18n.instance.t('connect')} failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 8),

          // Auto Polling toggle
          IconButton(
            icon: Icon(
              _pollingService.isRunning ? Icons.autorenew : Icons.pause_circle_outline,
              color: _pollingService.isRunning ? Colors.green : Colors.grey,
            ),
            tooltip: _pollingService.isRunning ? i18n.t('pollTooltipRunning') : i18n.t('pollTooltipPaused'),
            onPressed: () {
              setState(() {
                if (_pollingService.isRunning) {
                  _pollingService.stop();
                } else {
                  _pollingService.start();
                }
              });
            },
          ),
          const SizedBox(width: 6),

          // Save Workspace button
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: i18n.t('saveWorkspace'),
            onPressed: _saveWorkspace,
          ),
          const SizedBox(width: 6),

          // Theme Toggle Button
          if (widget.onToggleTheme != null)
            IconButton(
              icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
              tooltip: widget.isDarkMode ? i18n.t('themeLight') : i18n.t('themeDark'),
              onPressed: widget.onToggleTheme,
            ),
          if (widget.onToggleTheme != null)
            const SizedBox(width: 6),

          LanguagePickerButton(
            onLanguageChanged: () {
              setState(() {});
              widget.onLanguageChanged?.call();
            },
          ),
          const SizedBox(width: 8),

          WindowControls(brightness: theme.brightness),
        ],
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
                  icon: Icons.send_outlined,
                  selectedIcon: Icons.send,
                  labelText: i18n.t('tabCommands'),
                ),
                _buildRailDestination(
                  icon: Icons.sync_alt_outlined,
                  selectedIcon: Icons.sync_alt,
                  labelText: i18n.t('tabTraffic'),
                ),
                _buildRailDestination(
                  icon: Icons.construction_outlined,
                  selectedIcon: Icons.construction,
                  labelText: i18n.t('tabTools'),
                ),
                _buildRailDestination(
                  icon: Icons.show_chart_outlined,
                  selectedIcon: Icons.show_chart,
                  labelText: i18n.t('tabCharts'),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1),

          // Tab content
          Expanded(
            child: IndexedStack(
              key: ValueKey(i18n.currentLanguage.code),
              index: _selectedIndex,
              children: [
                RegisterViewTab(
                  client: _client,
                  pollingService: _pollingService,
                  connections: _connections,
                  activeConnection: _activeConfig,
                  onSelectConnection: _switchActiveConnection,
                  onConfigChanged: _onConfigChanged,
                  onAddSlave: _onAddSlaveToActiveConnection,
                ),
                ConnectionTab(
                  client: _client,
                  pollingService: _pollingService,
                  connections: _connections,
                  activeConnection: _activeConfig,
                  onSelectConnection: _switchActiveConnection,
                  onConfigChanged: _onConfigChanged,
                  onAddConnection: _onAddConnection,
                  onDeleteConnection: _onDeleteConnection,
                ),
                CommandsTab(
                  client: _client,
                  config: _activeConfig,
                ),
                const TrafficTab(),
                ToolsTab(client: _client),
                ChartTab(
                  pollingService: _pollingService,
                  config: _activeConfig,
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
                color: isConnected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(peerBadge, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${AppI18n.instance.t('connAlias')}: ${_activeConfig.displayName}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text('${AppI18n.instance.t('slavesList')}: ${_activeConfig.slaves.length}', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 20),
              Text(
                _pollingService.isRunning
                    ? '${AppI18n.instance.t('pollRunning')} (${_activeConfig.pollingIntervalMs}ms)'
                    : AppI18n.instance.t('pollPaused'),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 20),
              Text(AppI18n.instance.t('footerNote'), style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(ThemeData theme, AppI18n i18n) {
    final isConnected = _client.state == ModbusConnectionState.connected;
    final activeDesc = _activeConfig.mode == ModbusTransportMode.serialRtu
        ? (_activeConfig.serialPortName ?? 'COM')
        : (_activeConfig.mode == ModbusTransportMode.virtual ? 'Sim' : '${_activeConfig.ip}:${_activeConfig.port}');
    final activeTooltip = '${_activeConfig.displayName} ($activeDesc)\n${isConnected ? i18n.t('connected') : i18n.t('disconnected')}';

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
        const SizedBox(width: 12),

        // Connection selector dropdown in AppBar
        Tooltip(
          message: activeTooltip,
          waitDuration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.dividerColor),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ConnectionConfig>(
                value: _activeConfig,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                items: _connections.map((c) {
                  final desc = c.mode == ModbusTransportMode.serialRtu
                      ? (c.serialPortName ?? 'COM')
                      : (c.mode == ModbusTransportMode.virtual ? 'Sim' : '${c.ip}:${c.port}');
                  return DropdownMenuItem(
                    value: c,
                    child: Tooltip(
                      message: '${c.displayName} ($desc)',
                      waitDuration: const Duration(milliseconds: 200),
                      child: Text('🔌 ${c.displayName} ($desc)'),
                    ),
                  );
                }).toList(),
                onChanged: (newConn) {
                  if (newConn != null && newConn != _activeConfig) {
                    _switchActiveConnection(newConn);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          tooltip: i18n.t('addConnection'),
          onPressed: _onAddConnection,
        ),
      ],
    );
  }
}
