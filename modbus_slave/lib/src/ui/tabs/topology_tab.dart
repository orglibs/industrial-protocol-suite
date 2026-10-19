import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/slave_model.dart';
import '../../models/workspace_storage.dart';
import '../../protocol/modbus_server.dart';
import '../dialogs/batch_fill_dialog.dart';
import '../dialogs/edit_connection_dialog.dart';
import '../dialogs/edit_group_dialog.dart';
import '../dialogs/edit_slave_dialog.dart';
import '../dialogs/simulation_config_dialog.dart';

class TopologyTab extends StatefulWidget {
  final List<ConnectionConfig> connections;
  final VoidCallback onDataChanged;

  const TopologyTab({
    super.key,
    required this.connections,
    required this.onDataChanged,
  });

  @override
  State<TopologyTab> createState() => _TopologyTabState();
}

class _TopologyTabState extends State<TopologyTab> {
  ConnectionConfig? _selectedConnection;
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _syncSelection();
  }

  void _syncSelection() {
    if (widget.connections.isNotEmpty) {
      if (_selectedConnection == null || !widget.connections.contains(_selectedConnection)) {
        _selectedConnection = widget.connections.first;
      }
      if (_selectedConnection!.slaves.isNotEmpty) {
        if (_selectedSlave == null || !_selectedConnection!.slaves.contains(_selectedSlave)) {
          _selectedSlave = _selectedConnection!.slaves.first;
        }
        if (_selectedSlave!.groups.isNotEmpty) {
          if (_selectedGroup == null || !_selectedSlave!.groups.contains(_selectedGroup)) {
            _selectedGroup = _selectedSlave!.groups.first;
          }
        } else {
          _selectedGroup = null;
        }
      } else {
        _selectedSlave = null;
        _selectedGroup = null;
      }
    } else {
      _selectedConnection = null;
      _selectedSlave = null;
      _selectedGroup = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _syncSelection();

    return Scaffold(
      body: Column(
        children: [
          // Global Actions Bar
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
                      label: Text(AppI18n.instance.t('openAll')),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () async {
                        await ModbusServerManager.instance.startAll(widget.connections);
                        setState(() {});
                        widget.onDataChanged();
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.stop, size: 18),
                      label: Text(AppI18n.instance.t('closeAll')),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        await ModbusServerManager.instance.stopAll(widget.connections);
                        setState(() {});
                        widget.onDataChanged();
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
                      label: Text(AppI18n.instance.t('importWorkspace')),
                      onPressed: () async {
                        final path = WorkspaceStorage.defaultFilePath;
                        try {
                          final imported = await WorkspaceStorage.importFromFile(path);
                          setState(() {
                            widget.connections.clear();
                            widget.connections.addAll(imported);
                          });
                          widget.onDataChanged();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${AppI18n.instance.t('importWorkspace')}: $path')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${AppI18n.instance.t('parseError')}: $e')),
                            );
                          }
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: Text(AppI18n.instance.t('saveWorkspace')),
                      onPressed: () async {
                        await WorkspaceStorage.saveConnections(widget.connections);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${AppI18n.instance.t('saveWorkspace')} -> ${WorkspaceStorage.defaultFilePath}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 3 Columns: Connections -> Slaves -> Register Groups
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Column 1: Connections
                Expanded(flex: 3, child: _buildConnectionsColumn(theme)),
                const VerticalDivider(width: 1),
                // Column 2: Slaves under Connection
                Expanded(flex: 3, child: _buildSlavesColumn(theme)),
                const VerticalDivider(width: 1),
                // Column 3: Groups under Slave
                Expanded(flex: 4, child: _buildGroupsColumn(theme)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Column 1: Connections
  Widget _buildConnectionsColumn(ThemeData theme) {
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
                  '${AppI18n.instance.t('connServers')} (${widget.connections.length})',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: AppI18n.instance.t('newConn'),
                onPressed: () async {
                  final newConn = await showDialog<ConnectionConfig>(
                    context: context,
                    builder: (_) => const EditConnectionDialog(),
                  );
                  if (newConn != null) {
                    setState(() {
                      widget.connections.add(newConn);
                      _selectedConnection = newConn;
                    });
                    widget.onDataChanged();
                  }
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: widget.connections.isEmpty
              ? Center(child: Text(AppI18n.instance.t('noConnHint')))
              : ListView.builder(
                  itemCount: widget.connections.length,
                  itemBuilder: (context, idx) {
                    final conn = widget.connections[idx];
                    final isSelected = conn == _selectedConnection;
                    final isRunning = conn.isRunning;

                    return Card(
                      color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          conn.mode == ModbusTransportMode.serialRtu ? Icons.usb : Icons.router,
                          color: isRunning ? Colors.green : Colors.grey,
                        ),
                        title: Text(conn.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            conn.mode == ModbusTransportMode.serialRtu
                                ? '${conn.serialPortName} (${conn.baudRate} bps)'
                                : '${conn.ip}:${conn.port} (${conn.mode.label})',
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
                              tooltip: isRunning ? AppI18n.instance.t('stopService') : AppI18n.instance.t('startListen'),
                              onPressed: () async {
                                if (isRunning) {
                                  await ModbusServerManager.instance.stopServer(conn);
                                } else {
                                  try {
                                    await ModbusServerManager.instance.startServer(conn);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${AppI18n.instance.t('startListen')} failed: $e')),
                                      );
                                    }
                                  }
                                }
                                setState(() {});
                                widget.onDataChanged();
                              },
                            ),
                            PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  final edited = await showDialog<ConnectionConfig>(
                                    context: context,
                                    builder: (_) => EditConnectionDialog(initialConfig: conn),
                                  );
                                  if (edited != null) {
                                    setState(() {});
                                    widget.onDataChanged();
                                  }
                                } else if (val == 'delete') {
                                  if (conn.isRunning) {
                                    await ModbusServerManager.instance.stopServer(conn);
                                  }
                                  setState(() {
                                    widget.connections.remove(conn);
                                    if (_selectedConnection == conn) _selectedConnection = null;
                                  });
                                  widget.onDataChanged();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(AppI18n.instance.t('editParams'))),
                                PopupMenuItem(value: 'delete', child: Text(AppI18n.instance.t('deleteConn'), style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedConnection = conn;
                            _selectedSlave = conn.slaves.isNotEmpty ? conn.slaves.first : null;
                            _selectedGroup = _selectedSlave?.groups.isNotEmpty == true ? _selectedSlave!.groups.first : null;
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

  // Column 2: Slaves under Connection
  Widget _buildSlavesColumn(ThemeData theme) {
    final slaves = _selectedConnection?.slaves ?? [];

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
                  '${AppI18n.instance.t('slavesList')} (${slaves.length})',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: AppI18n.instance.t('newSlave'),
                onPressed: _selectedConnection == null
                    ? null
                    : () async {
                        final nextId = (slaves.map((s) => s.slaveId).fold(0, (a, b) => a > b ? a : b)) + 1;
                        final newSlave = await showDialog<SlaveModel>(
                          context: context,
                          builder: (_) => EditSlaveDialog(
                            initialSlave: ConnectionConfig.createDefaultSlave(nextId.clamp(1, 247), 'Slave$nextId'),
                          ),
                        );
                        if (newSlave != null) {
                          setState(() {
                            _selectedConnection!.slaves.add(newSlave);
                            _selectedSlave = newSlave;
                          });
                          widget.onDataChanged();
                        }
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selectedConnection == null
              ? Center(child: Text(AppI18n.instance.t('selectConnFirst')))
              : slaves.isEmpty
                  ? Center(child: Text(AppI18n.instance.t('noSlaveHint')))
                  : ListView.builder(
                      itemCount: slaves.length,
                      itemBuilder: (context, idx) {
                        final s = slaves[idx];
                        final isSelected = s == _selectedSlave;

                        return Card(
                          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(s.slaveId.toString()),
                            ),
                            title: Text(s.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${AppI18n.instance.t('regGroups')}: ${s.groups.length} | ${AppI18n.instance.t('respDelay')}: ${s.responseDelay}ms | ${s.byteOrder.label}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  final edited = await showDialog<SlaveModel>(
                                    context: context,
                                    builder: (_) => EditSlaveDialog(initialSlave: s),
                                  );
                                  if (edited != null) {
                                    setState(() {});
                                    widget.onDataChanged();
                                  }
                                } else if (val == 'copy') {
                                  // Replicates MSE Copy Slave
                                  final nextId = (slaves.map((e) => e.slaveId).fold(0, (a, b) => a > b ? a : b)) + 1;
                                  final clone = s.copyWith(
                                    name: '${s.displayName} (${AppI18n.instance.t('copy')})',
                                    nameKey: null,
                                    slaveId: nextId.clamp(1, 247),
                                  );
                                  setState(() {
                                    _selectedConnection!.slaves.add(clone);
                                    _selectedSlave = clone;
                                  });
                                  widget.onDataChanged();
                                } else if (val == 'delete') {
                                  setState(() {
                                    _selectedConnection!.slaves.remove(s);
                                    if (_selectedSlave == s) _selectedSlave = null;
                                  });
                                  widget.onDataChanged();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(AppI18n.instance.t('editSlave'))),
                                PopupMenuItem(value: 'copy', child: Text(AppI18n.instance.t('copySlave'))),
                                PopupMenuItem(value: 'delete', child: Text(AppI18n.instance.t('deleteSlave'), style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedSlave = s;
                                _selectedGroup = s.groups.isNotEmpty ? s.groups.first : null;
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

  // Column 3: Groups under Slave
  Widget _buildGroupsColumn(ThemeData theme) {
    final groups = _selectedSlave?.groups ?? [];

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
                  '${AppI18n.instance.t('regGroups')} (${groups.length})',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: AppI18n.instance.t('addGroup'),
                onPressed: _selectedSlave == null
                    ? null
                    : () async {
                        final newGroup = await showDialog<RegisterGroupModel>(
                          context: context,
                          builder: (_) => const EditGroupDialog(),
                        );
                        if (newGroup != null) {
                          setState(() {
                            _selectedSlave!.groups.add(newGroup);
                            _selectedGroup = newGroup;
                          });
                          widget.onDataChanged();
                        }
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _selectedSlave == null
              ? Center(child: Text(AppI18n.instance.t('selectSlaveFirst')))
              : groups.isEmpty
                  ? Center(child: Text(AppI18n.instance.t('noGroupHint')))
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, idx) {
                        final g = groups[idx];
                        final isSelected = g == _selectedGroup;

                        return Card(
                          color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.4) : null,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                g.registerType.prefix,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                            title: Text(g.displayGroupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${AppI18n.instance.t('regType')}: ${g.registerType.label} | ${AppI18n.instance.t('startAddr')}: ${g.startAddress} | ${AppI18n.instance.t('pointsCount')}: ${g.quantity}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (val) async {
                                if (val == 'edit') {
                                  final edited = await showDialog<RegisterGroupModel>(
                                    context: context,
                                    builder: (_) => EditGroupDialog(initialGroup: g),
                                  );
                                  if (edited != null) {
                                    setState(() {});
                                    widget.onDataChanged();
                                  }
                                } else if (val == 'batch_fill') {
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (_) => BatchFillDialog(group: g),
                                  );
                                  setState(() {});
                                  widget.onDataChanged();
                                } else if (val == 'batch_sim') {
                                  final simCfg = await showDialog<dynamic>(
                                    context: context,
                                    builder: (_) => SimulationConfigDialog(
                                      initialConfig: g.registers.first.simulation,
                                      title: '${AppI18n.instance.t('batchWave')} (${g.displayGroupName})',
                                    ),
                                  );
                                  if (simCfg != null) {
                                    g.batchConfigureSimulation(simCfg);
                                    setState(() {});
                                    widget.onDataChanged();
                                  }
                                } else if (val == 'reset') {
                                  g.resetAll();
                                  setState(() {});
                                  widget.onDataChanged();
                                } else if (val == 'delete') {
                                  setState(() {
                                    _selectedSlave!.groups.remove(g);
                                    if (_selectedGroup == g) _selectedGroup = null;
                                  });
                                  widget.onDataChanged();
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(AppI18n.instance.t('editGroup'))),
                                PopupMenuItem(value: 'batch_fill', child: Text(AppI18n.instance.t('batchFill'))),
                                PopupMenuItem(value: 'batch_sim', child: Text(AppI18n.instance.t('batchWave'))),
                                PopupMenuItem(value: 'reset', child: Text(AppI18n.instance.t('resetAll'))),
                                PopupMenuItem(value: 'delete', child: Text(AppI18n.instance.t('deleteGroup'), style: const TextStyle(color: Colors.red))),
                              ],
                            ),
                            onTap: () => setState(() => _selectedGroup = g),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
