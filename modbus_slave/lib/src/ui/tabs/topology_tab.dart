import 'package:flutter/material.dart';
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
            child: Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('启动全部连接 (Open All)'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () async {
                    await ModbusServerManager.instance.startAll(widget.connections);
                    setState(() {});
                    widget.onDataChanged();
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('停止全部连接 (Close All)'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () async {
                    await ModbusServerManager.instance.stopAll(widget.connections);
                    setState(() {});
                    widget.onDataChanged();
                  },
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: const Text('导入工作区'),
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
                          SnackBar(content: Text('已从 $path 成功导入')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('导入失败: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('保存工作区'),
                  onPressed: () async {
                    await WorkspaceStorage.saveConnections(widget.connections);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已保存至 ${WorkspaceStorage.defaultFilePath}')),
                      );
                    }
                  },
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
              Text('连接服务端 (${widget.connections.length})', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: '新建连接 (New Connection)',
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
              ? const Center(child: Text('暂无连接，请点击右上角添加'))
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
                        title: Text(conn.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          conn.mode == ModbusTransportMode.serialRtu
                              ? '${conn.serialPortName} (${conn.baudRate} bps)'
                              : '${conn.ip}:${conn.port} (${conn.mode.name.toUpperCase()})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isRunning ? Icons.stop_circle : Icons.play_circle,
                                color: isRunning ? Colors.red : Colors.green,
                              ),
                              tooltip: isRunning ? '停止服务' : '启动服务',
                              onPressed: () async {
                                if (isRunning) {
                                  await ModbusServerManager.instance.stopServer(conn);
                                } else {
                                  try {
                                    await ModbusServerManager.instance.startServer(conn);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('启动服务失败: $e')),
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
                                const PopupMenuItem(value: 'edit', child: Text('编辑参数')),
                                const PopupMenuItem(value: 'delete', child: Text('删除连接', style: TextStyle(color: Colors.red))),
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
              Text('从站设备 (${slaves.length})', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: '添加从站 (New Slave)',
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
              ? const Center(child: Text('请先在左侧选择一个连接'))
              : slaves.isEmpty
                  ? const Center(child: Text('当前连接下无从站设备，请点击右上角添加'))
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
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '组数: ${s.groups.length} | 延迟: ${s.responseDelay}ms | ${s.byteOrder.name.toUpperCase()}',
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
                                    name: '${s.name} (副本)',
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
                                const PopupMenuItem(value: 'edit', child: Text('编辑从站')),
                                const PopupMenuItem(value: 'copy', child: Text('复制从站 (Copy Slave)')),
                                const PopupMenuItem(value: 'delete', child: Text('删除从站', style: TextStyle(color: Colors.red))),
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
              Text('寄存器组 (${groups.length})', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                tooltip: '添加寄存器组 (Add Register Group)',
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
              ? const Center(child: Text('请先选择一个从站设备'))
              : groups.isEmpty
                  ? const Center(child: Text('当前从站下无寄存器组，请点击右上角添加'))
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
                            title: Text(g.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '类型: ${g.registerType.label} | 起始: ${g.startAddress} | 点数: ${g.quantity}',
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
                                      title: '全组寄存器波形配置 (${g.groupName})',
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
                                const PopupMenuItem(value: 'edit', child: Text('编辑寄存器组')),
                                const PopupMenuItem(value: 'batch_fill', child: Text('批量填充数值 (Batch Fill)')),
                                const PopupMenuItem(value: 'batch_sim', child: Text('全组波形配置 (Wave Simulation)')),
                                const PopupMenuItem(value: 'reset', child: Text('整组数值清零')),
                                const PopupMenuItem(value: 'delete', child: Text('删除寄存器组', style: TextStyle(color: Colors.red))),
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
