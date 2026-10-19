import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../server/client_session.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';
import '../../server/workspace_storage.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/edit_connection_dialog.dart';
import '../dialogs/edit_station_dialog.dart';

class ServerTab extends StatefulWidget {
  final List<Iec104ConnectionConfig>? connections;
  final Iec104Server? server;
  final VoidCallback? onDataChanged;

  const ServerTab({
    super.key,
    this.connections,
    this.server,
    this.onDataChanged,
  });

  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab> {
  late List<Iec104ConnectionConfig> _connections;
  Iec104ConnectionConfig? _selectedConnection;
  Station? _selectedStation;

  // Controllers for selected connection parameters
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _t0Ctrl;
  late TextEditingController _t1Ctrl;
  late TextEditingController _t2Ctrl;
  late TextEditingController _t3Ctrl;
  late TextEditingController _kCtrl;
  late TextEditingController _wCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initConnections();
    _syncSelection();
    _initControllers();
    _listenToStreams();
  }

  @override
  void didUpdateWidget(covariant ServerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connections != oldWidget.connections || widget.server != oldWidget.server) {
      _initConnections();
      _syncSelection();
      _syncControllersFromConnection();
    }
  }

  void _initConnections() {
    if (widget.connections != null && widget.connections!.isNotEmpty) {
      _connections = widget.connections!;
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
      _connections = [];
    }
  }

  void _initControllers() {
    final c = _selectedConnection;
    _hostCtrl = TextEditingController(text: c?.host ?? '0.0.0.0');
    _portCtrl = TextEditingController(text: (c?.port ?? 2404).toString());
    _t0Ctrl = TextEditingController(text: (c?.t0 ?? 30).toString());
    _t1Ctrl = TextEditingController(text: (c?.t1 ?? 15).toString());
    _t2Ctrl = TextEditingController(text: (c?.t2 ?? 10).toString());
    _t3Ctrl = TextEditingController(text: (c?.t3 ?? 20).toString());
    _kCtrl = TextEditingController(text: (c?.k ?? 12).toString());
    _wCtrl = TextEditingController(text: (c?.w ?? 8).toString());
  }

  void _syncControllersFromConnection() {
    final c = _selectedConnection;
    if (c == null) return;
    _hostCtrl.text = c.host;
    _portCtrl.text = c.port.toString();
    _t0Ctrl.text = c.t0.toString();
    _t1Ctrl.text = c.t1.toString();
    _t2Ctrl.text = c.t2.toString();
    _t3Ctrl.text = c.t3.toString();
    _kCtrl.text = c.k.toString();
    _wCtrl.text = c.w.toString();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _t0Ctrl.dispose();
    _t1Ctrl.dispose();
    _t2Ctrl.dispose();
    _t3Ctrl.dispose();
    _kCtrl.dispose();
    _wCtrl.dispose();
    super.dispose();
  }

  void _syncSelection() {
    if (_connections.isNotEmpty) {
      if (_selectedConnection == null || !_connections.contains(_selectedConnection)) {
        _selectedConnection = _connections.first;
      }
      final stations = _selectedConnection?.stations ?? [];
      if (stations.isNotEmpty) {
        if (_selectedStation == null || !stations.contains(_selectedStation)) {
          _selectedStation = stations.first;
        }
      } else {
        _selectedStation = null;
      }
    } else {
      _selectedConnection = null;
      _selectedStation = null;
    }
  }

  void _listenToStreams() {
    for (final conn in _connections) {
      conn.server.statusStream.listen((_) {
        if (mounted) setState(() {});
      });
      conn.server.clientsStream.listen((_) {
        if (mounted) setState(() {});
      });
      conn.server.stationsStream.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _applyParameters() async {
    final c = _selectedConnection;
    if (c == null) return;

    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 2404;
    final t0 = int.tryParse(_t0Ctrl.text.trim()) ?? 30;
    final t1 = int.tryParse(_t1Ctrl.text.trim()) ?? 15;
    final t2 = int.tryParse(_t2Ctrl.text.trim()) ?? 10;
    final t3 = int.tryParse(_t3Ctrl.text.trim()) ?? 20;
    final k = int.tryParse(_kCtrl.text.trim()) ?? 12;
    final w = int.tryParse(_wCtrl.text.trim()) ?? 8;

    c.host = host;
    c.port = port;
    c.t0 = t0;
    c.t1 = t1;
    c.t2 = t2;
    c.t3 = t3;
    c.k = k;
    c.w = w;

    if (c.isRunning) {
      // Restart with new parameters
      await Iec104ServerManager.instance.stopServer(c);
      await Iec104ServerManager.instance.startServer(c);
    }

    setState(() {});
    widget.onDataChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('save')), duration: const Duration(seconds: 1)),
      );
    }
  }

  Future<void> _runVerification() async {
    final c = _selectedConnection;
    if (c == null) return;

    setState(() => _isLoading = true);
    try {
      final results = await c.server.runAutomatedVerification();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.verified, color: Colors.green),
              SizedBox(width: 8),
              Text('IEC 104 Self-Test Results'),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (ctx, i) {
                final text = results[i];
                final isSuccess = !text.contains('FAIL');
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle : Icons.error,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppI18n.instance.t('confirm')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppI18n.instance.t('parseError')}: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    _syncSelection();

    return Scaffold(
      body: Column(
        children: [
          // Global Actions Bar matching modbus_slave TopologyTab
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(i18n.t('openAll')),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () async {
                        await Iec104ServerManager.instance.startAll(_connections);
                        setState(() {});
                        widget.onDataChanged?.call();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(i18n.t('closeAll')),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        await Iec104ServerManager.instance.stopAll(_connections);
                        setState(() {});
                        widget.onDataChanged?.call();
                      },
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: Text(i18n.t('importWorkspace')),
                      onPressed: () async {
                        final path = WorkspaceStorage.getWorkspaceFilePath();
                        try {
                          final imported = await WorkspaceStorage.loadConnections();
                          setState(() {
                            _connections.clear();
                            _connections.addAll(imported);
                            _syncSelection();
                            _syncControllersFromConnection();
                          });
                          widget.onDataChanged?.call();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${i18n.t('importWorkspace')}: $path')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${i18n.t('parseError')}: $e')),
                            );
                          }
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(i18n.t('saveWorkspace')),
                      onPressed: () async {
                        await WorkspaceStorage.saveConnections(_connections);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${i18n.t('saveWorkspace')} -> ${WorkspaceStorage.getWorkspaceFilePath()}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3 Columns: Connections -> Slaves (Stations) -> Connection Details & Clients
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column 1: Connection Servers
                Expanded(flex: 3, child: _buildConnectionsColumn(theme, i18n)),
                const VerticalDivider(width: 1),
                // Column 2: Slaves (Stations) under selected Connection
                Expanded(flex: 3, child: _buildSlavesColumn(theme, i18n)),
                const VerticalDivider(width: 1),
                // Column 3: Parameters & Connected Clients
                Expanded(flex: 4, child: _buildDetailsColumn(theme, i18n)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Column 1: Connections
  Widget _buildConnectionsColumn(ThemeData theme, AppI18n i18n) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${i18n.t('connServers')} (${_connections.length})',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: i18n.t('newConn'),
                onPressed: () async {
                  final newConn = await showDialog<Iec104ConnectionConfig>(
                    context: context,
                    builder: (_) => const EditConnectionDialog(),
                  );
                  if (newConn != null) {
                    setState(() {
                      _connections.add(newConn);
                      _selectedConnection = newConn;
                      _syncSelection();
                      _syncControllersFromConnection();
                    });
                    widget.onDataChanged?.call();
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _connections.isEmpty
              ? Center(child: Text(i18n.t('noConnHint')))
              : ListView.builder(
                  itemCount: _connections.length,
                  itemBuilder: (context, idx) {
                    final conn = _connections[idx];
                    final isSelected = conn == _selectedConnection;
                    final isRunning = conn.isRunning;

                    return Card(
                      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          Icons.router,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                        title: Text(conn.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            '${conn.host}:${conn.port} | ${conn.stations.length} ${i18n.t('coa')}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isRunning ? Icons.stop_circle : Icons.play_circle,
                                color: isRunning ? Colors.red : Colors.green,
                              ),
                              tooltip: isRunning ? i18n.t('stopService') : i18n.t('startListen'),
                              onPressed: () async {
                                if (isRunning) {
                                  await Iec104ServerManager.instance.stopServer(conn);
                                } else {
                                  try {
                                    await Iec104ServerManager.instance.startServer(conn);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${i18n.t('startListen')} failed: $e')),
                                      );
                                    }
                                  }
                                }
                                setState(() {});
                                widget.onDataChanged?.call();
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  final edited = await showDialog<Iec104ConnectionConfig>(
                                    context: context,
                                    builder: (_) => EditConnectionDialog(initialConfig: conn),
                                  );
                                  if (edited != null) {
                                    setState(() {
                                      _syncControllersFromConnection();
                                    });
                                    widget.onDataChanged?.call();
                                  }
                                } else if (val == 'delete') {
                                  if (conn.isRunning) {
                                    await Iec104ServerManager.instance.stopServer(conn);
                                  }
                                  setState(() {
                                    _connections.remove(conn);
                                    if (_selectedConnection == conn) {
                                      _selectedConnection = null;
                                    }
                                    _syncSelection();
                                    _syncControllersFromConnection();
                                  });
                                  widget.onDataChanged?.call();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(i18n.t('editParams'))),
                                PopupMenuItem(value: 'delete', child: Text(i18n.t('deleteConn'), style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedConnection = conn;
                            _syncSelection();
                            _syncControllersFromConnection();
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Column 2: Slaves (Stations) under selected Connection
  Widget _buildSlavesColumn(ThemeData theme, AppI18n i18n) {
    final stations = _selectedConnection?.stations ?? [];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${i18n.t('slavesList')} (${stations.length})',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: i18n.t('newSlave'),
                onPressed: _selectedConnection == null
                    ? null
                    : () async {
                        showDialog(
                          context: context,
                          builder: (_) => AddStationDialog(
                            connection: _selectedConnection,
                            onAdded: (newCa) {
                              setState(() {
                                _selectedStation = _selectedConnection?.server.stations[newCa];
                              });
                              widget.onDataChanged?.call();
                            },
                          ),
                        );
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selectedConnection == null
              ? Center(child: Text(i18n.t('selectConnFirst')))
              : stations.isEmpty
                  ? Center(child: Text(i18n.t('noSlaveHint')))
                  : ListView.builder(
                      itemCount: stations.length,
                      itemBuilder: (context, idx) {
                        final s = stations[idx];
                        final isSelected = s == _selectedStation;

                        return Card(
                          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.domain, color: Colors.blueAccent),
                            title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('CA: ${s.commonAddress} | ${s.points.length} ${i18n.t('pointsCount')}', style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined, size: 20),
                                  tooltip: i18n.t('editStation'),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => EditStationDialog(
                                        connection: _selectedConnection,
                                        station: s,
                                        onStationChanged: (newCa) {
                                          setState(() {
                                            _selectedStation = _selectedConnection?.server.stations[newCa];
                                          });
                                          widget.onDataChanged?.call();
                                        },
                                        onStationDeleted: () {
                                          setState(() {
                                            _syncSelection();
                                          });
                                          widget.onDataChanged?.call();
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() => _selectedStation = s);
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // Column 3: Parameters & Connected Clients
  Widget _buildDetailsColumn(ThemeData theme, AppI18n i18n) {
    final conn = _selectedConnection;
    if (conn == null) {
      return Center(child: Text(i18n.t('selectConnFirst')));
    }

    final clients = conn.server.clients;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection Status & Parameters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${conn.displayName} - ${i18n.t('editParams')}',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: conn.isRunning ? Colors.green.withOpacity(0.12) : Colors.grey.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: conn.isRunning ? Colors.green : Colors.grey),
                        ),
                        child: Text(
                          conn.isRunning ? i18n.t('serversRunning') : i18n.t('allServersStopped'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: conn.isRunning ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Host IP',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: i18n.t('port'),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _t0Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 't0 (s)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t1Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 't1 (s)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _t2Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 't2 (s)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _t3Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 't3 (s)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _kCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'k (APDU)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _wCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'w (APDU)', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(i18n.t('save')),
                        onPressed: _applyParameters,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.verified, size: 16),
                        label: const Text('Self-Test'),
                        onPressed: _isLoading ? null : _runVerification,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Connected Clients Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${i18n.t('connectedMasters')} (${clients.length})',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (clients.isNotEmpty)
                        Text(
                          'Rx: ${conn.server.rxCount} | Tx: ${conn.server.txCount}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (clients.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          i18n.t('noClientsConnected'),
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: clients.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, i) {
                        final ClientSession c = clients[i];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.computer, color: Colors.green, size: 20),
                          title: Text(c.remoteAddress),
                          subtitle: Text(
                            'State: ${c.isDataTransferActive ? "Active" : "Standby"} | Rx: ${c.rxFrameCount} Tx: ${c.txFrameCount}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                            tooltip: 'Disconnect',
                            onPressed: () {
                              conn.server.disconnectClient(c);
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
