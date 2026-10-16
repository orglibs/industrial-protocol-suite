import 'package:flutter/material.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/register_model.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_client.dart';
import '../../protocol/modbus_data_types.dart';
import '../../services/polling_service.dart';
import '../dialogs/write_single_coil_dialog.dart';
import '../dialogs/write_single_register_dialog.dart';
import '../dialogs/write_multiple_registers_dialog.dart';
import '../dialogs/edit_group_dialog.dart';

class RegisterViewTab extends StatefulWidget {
  final ModbusClient client;
  final PollingService pollingService;
  final List<ConnectionConfig> connections;
  final ConnectionConfig activeConnection;
  final ValueChanged<ConnectionConfig> onSelectConnection;
  final VoidCallback onConfigChanged;
  final VoidCallback onAddSlave;

  const RegisterViewTab({
    super.key,
    required this.client,
    required this.pollingService,
    required this.connections,
    required this.activeConnection,
    required this.onSelectConnection,
    required this.onConfigChanged,
    required this.onAddSlave,
  });

  @override
  State<RegisterViewTab> createState() => _RegisterViewTabState();
}

class _RegisterViewTabState extends State<RegisterViewTab> {
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;
  ModbusByteOrder _byteOrder = ModbusByteOrder.abcd;

  @override
  void initState() {
    super.initState();
    _initSelection();
    widget.pollingService.onGroupUpdated.listen((updatedGroup) {
      if (mounted && updatedGroup == _selectedGroup) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant RegisterViewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection ||
        _selectedSlave == null ||
        !widget.activeConnection.slaves.contains(_selectedSlave)) {
      _initSelection();
    }
  }

  void _initSelection() {
    if (widget.activeConnection.slaves.isNotEmpty) {
      _selectedSlave = widget.activeConnection.slaves.first;
      _byteOrder = _selectedSlave!.byteOrder;
      if (_selectedSlave!.groups.isNotEmpty) {
        _selectedGroup = _selectedSlave!.groups.first;
      } else {
        _selectedGroup = null;
      }
    } else {
      _selectedSlave = null;
      _selectedGroup = null;
    }
  }

  void _scanCurrentGroup() async {
    if (_selectedSlave == null || _selectedGroup == null) return;
    await widget.pollingService.scanGroup(_selectedSlave!, _selectedGroup!);
    if (mounted) setState(() {});
  }

  void _onEditCell(RegisterModel reg) async {
    if (_selectedGroup == null || _selectedSlave == null) return;

    if (_selectedGroup!.registerType == ModbusRegisterType.coils) {
      final res = await WriteSingleCoilDialog.show(
        context,
        client: widget.client,
        slaveId: _selectedSlave!.slaveId,
        address: reg.address,
        initialValue: reg.rawValue != 0,
      );
      if (res == true) {
        _scanCurrentGroup();
      }
    } else if (_selectedGroup!.registerType == ModbusRegisterType.holdingRegisters) {
      final res = await WriteSingleRegisterDialog.show(
        context,
        client: widget.client,
        slaveId: _selectedSlave!.slaveId,
        address: reg.address,
        initialValue: reg.rawValue,
      );
      if (res == true) {
        _scanCurrentGroup();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedGroup!.registerType.label} 为只读类型，不支持写入操作'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onEditAliasAndComment(RegisterModel reg) {
    final aliasCtrl = TextEditingController(text: reg.alias ?? '');
    final commentCtrl = TextEditingController(text: reg.comment ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑点号信息 [地址: ${reg.address}]'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aliasCtrl,
              decoration: const InputDecoration(
                labelText: '点位名称 / 别名 (Alias)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: '说明备注 (Comment)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                reg.alias = aliasCtrl.text.trim().isEmpty ? null : aliasCtrl.text.trim();
                reg.comment = commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim();
              });
              widget.onConfigChanged();
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeConnection.slaves.isEmpty) {
      return Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.device_unknown, size: 64, color: Colors.blueGrey),
                const SizedBox(height: 16),
                Text(
                  '连接【${widget.activeConnection.name}】暂无从站设备',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('请为该连接添加从站后，方可查看其寄存器点表', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add),
                  label: const Text('添加从站到此连接 (Add Slave)'),
                  onPressed: widget.onAddSlave,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedSlave == null || !widget.activeConnection.slaves.contains(_selectedSlave)) {
      _selectedSlave = widget.activeConnection.slaves.first;
    }

    if (_selectedGroup == null || !_selectedSlave!.groups.contains(_selectedGroup)) {
      _selectedGroup = _selectedSlave!.groups.isNotEmpty ? _selectedSlave!.groups.first : null;
    }

    final theme = Theme.of(context);

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Connection Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    DropdownButton<ConnectionConfig>(
                      value: widget.activeConnection,
                      underline: const SizedBox(),
                      items: widget.connections.map((c) {
                        final desc = c.mode == ModbusTransportMode.serialRtu
                            ? (c.serialPortName ?? '串口')
                            : (c.mode == ModbusTransportMode.virtual ? '虚拟' : '${c.ip}:${c.port}');
                        return DropdownMenuItem(
                          value: c,
                          child: Text('连接: ${c.name} ($desc)', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (c) {
                        if (c != null && c != widget.activeConnection) {
                          widget.onSelectConnection(c);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Slave dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.developer_board, size: 18, color: Colors.teal),
                    const SizedBox(width: 6),
                    DropdownButton<SlaveModel>(
                      value: _selectedSlave,
                      underline: const SizedBox(),
                      items: widget.activeConnection.slaves.map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('从站: ${s.name} [ID: ${s.slaveId}]', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (s) {
                        setState(() {
                          _selectedSlave = s;
                          _byteOrder = s?.byteOrder ?? ModbusByteOrder.abcd;
                          _selectedGroup = s?.groups.isNotEmpty == true ? s!.groups.first : null;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Group dropdown
              if (_selectedSlave != null && _selectedSlave!.groups.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      DropdownButton<RegisterGroupModel>(
                        value: _selectedGroup,
                        underline: const SizedBox(),
                        items: _selectedSlave!.groups.map((g) {
                          return DropdownMenuItem(
                            value: g,
                            child: Text('${g.groupName} [${g.registerType.prefix}] (点数:${g.quantity})'),
                          );
                        }).toList(),
                        onChanged: (g) {
                          setState(() {
                            _selectedGroup = g;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Byte Order
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('字节序: '),
                    DropdownButton<ModbusByteOrder>(
                      value: _byteOrder,
                      underline: const SizedBox(),
                      items: ModbusByteOrder.values.map((order) {
                        return DropdownMenuItem(
                          value: order,
                          child: Text(order.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() {
                            _byteOrder = v;
                            _selectedSlave?.byteOrder = v;
                          });
                          widget.onConfigChanged();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Scan Once
              FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('单次刷新'),
                onPressed: _scanCurrentGroup,
              ),

              // Batch Write (for holding registers)
              if (_selectedGroup?.registerType == ModbusRegisterType.holdingRegisters)
                OutlinedButton.icon(
                  icon: const Icon(Icons.playlist_add_check, size: 18),
                  label: const Text('批量写 FC16'),
                  onPressed: () async {
                    if (_selectedSlave == null || _selectedGroup == null) return;
                    final res = await WriteMultipleRegistersDialog.show(
                      context,
                      client: widget.client,
                      slaveId: _selectedSlave!.slaveId,
                      startAddress: _selectedGroup!.startAddress,
                    );
                    if (res == true) _scanCurrentGroup();
                  },
                ),

              // Edit Group
              if (_selectedGroup != null)
                IconButton(
                  icon: const Icon(Icons.settings, size: 20),
                  tooltip: '修改组配置',
                  onPressed: () async {
                    final res = await EditGroupDialog.show(context, group: _selectedGroup);
                    if (res != null) {
                      setState(() {});
                      widget.onConfigChanged();
                    }
                  },
                ),
            ],
          ),
        ),

        // Group Status Bar
        if (_selectedGroup != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
            child: Row(
              children: [
                Icon(
                  _selectedGroup!.lastScanStatus?.contains('成功') == true
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 16,
                  color: _selectedGroup!.lastScanStatus?.contains('成功') == true
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  '最新扫描状态: ${_selectedGroup!.lastScanStatus ?? "尚未采集"}  |  耗时: ${_selectedGroup!.lastLatencyMs}ms  |  成功: ${_selectedGroup!.successCount} 次  |  异常: ${_selectedGroup!.errorCount} 次',
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                ),
                const Spacer(),
                Text(
                  '上次更新: ${_selectedGroup!.lastScanTime != null ? _selectedGroup!.lastScanTime.toString().substring(11, 19) : "--:--:--"}',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),

        // Main Table
        Expanded(
          child: _selectedGroup == null
              ? const Center(child: Text('请先为从站添加寄存器任务组'))
              : _buildRegistersTable(),
        ),
      ],
    );
  }

  Widget _buildRegistersTable() {
    final theme = Theme.of(context);
    final group = _selectedGroup!;
    final slave = _selectedSlave!;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(theme.colorScheme.surfaceVariant.withOpacity(0.2)),
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: const [
            DataColumn(label: Text('地址 (PLC/原生)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('点位别名 / 描述', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('原始十六进制 (Hex)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('解析数值 (双击写入)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('数据格式', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('备注说明', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('快捷操作', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: group.registers.asMap().entries.map((entry) {
            final idx = entry.key;
            final reg = entry.value;

            // Neighbor words for 32/64 bit parsing
            final neighborWords = <int>[];
            for (int k = idx + 1; k < group.registers.length && k <= idx + 4; k++) {
              neighborWords.add(group.registers[k].rawValue);
            }

            final displayStr = reg.getDisplayValue(_byteOrder, neighborWords);
            final hexStr = '0x${(reg.rawValue & 0xFFFF).toRadixString(16).padLeft(4, "0").toUpperCase()}';
            final formattedAddr = slave.formatAddress(reg.address, group.registerType);

            final isCoilOrDiscrete = group.registerType == ModbusRegisterType.coils ||
                group.registerType == ModbusRegisterType.discreteInputs;

            return DataRow(
              cells: [
                // Address
                DataCell(
                  Text('$formattedAddr (${reg.address})', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                  onDoubleTap: () => _onEditAliasAndComment(reg),
                ),
                // Alias
                DataCell(
                  InkWell(
                    onTap: () => _onEditAliasAndComment(reg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(reg.alias ?? '未命名点号', style: TextStyle(color: reg.alias != null ? Colors.black87 : Colors.grey)),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                // Raw Hex
                DataCell(
                  Text(hexStr, style: const TextStyle(fontFamily: 'monospace', color: Colors.blueGrey)),
                ),
                // Parsed Value
                DataCell(
                  InkWell(
                    onDoubleTap: () => _onEditCell(reg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCoilOrDiscrete
                            ? (reg.rawValue != 0 ? Colors.green.shade50 : Colors.red.shade50)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isCoilOrDiscrete
                              ? (reg.rawValue != 0 ? Colors.green.shade300 : Colors.red.shade300)
                              : Colors.blue.shade200,
                        ),
                      ),
                      child: Text(
                        displayStr,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: isCoilOrDiscrete
                              ? (reg.rawValue != 0 ? Colors.green.shade800 : Colors.red.shade800)
                              : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
                // Format Dropdown
                DataCell(
                  DropdownButton<RegisterDataFormat>(
                    value: reg.valueFormat,
                    underline: const SizedBox(),
                    items: RegisterDataFormat.values.map((f) {
                      return DropdownMenuItem(value: f, child: Text(f.label, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (fmt) {
                      if (fmt != null) {
                        setState(() {
                          reg.valueFormat = fmt;
                        });
                        widget.onConfigChanged();
                      }
                    },
                  ),
                ),
                // Comment
                DataCell(
                  InkWell(
                    onTap: () => _onEditAliasAndComment(reg),
                    child: Text(reg.comment ?? '-', style: const TextStyle(color: Colors.grey)),
                  ),
                ),
                // Action
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (group.registerType == ModbusRegisterType.coils)
                        IconButton(
                          icon: Icon(
                            reg.rawValue != 0 ? Icons.toggle_on : Icons.toggle_off,
                            color: reg.rawValue != 0 ? Colors.green : Colors.grey,
                            size: 28,
                          ),
                          tooltip: '切换线圈状态 (FC 05)',
                          onPressed: () async {
                            final nextVal = reg.rawValue == 0;
                            try {
                              await widget.client.writeSingleCoil(
                                unitId: slave.slaveId,
                                address: reg.address,
                                value: nextVal,
                              );
                              _scanCurrentGroup();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('写入线圈失败: $e')),
                                );
                              }
                            }

                          },
                        ),
                      if (group.registerType == ModbusRegisterType.holdingRegisters)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          tooltip: '写入保持寄存器值 (FC 06)',
                          onPressed: () => _onEditCell(reg),
                        ),
                      if (group.registerType == ModbusRegisterType.discreteInputs ||
                          group.registerType == ModbusRegisterType.inputRegisters)
                        const Chip(
                          label: Text('只读', style: TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
