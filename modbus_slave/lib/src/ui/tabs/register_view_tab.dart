import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../models/register_group.dart';
import '../../models/register_model.dart';
import '../../models/slave_model.dart';
import '../../protocol/modbus_data_types.dart';
import '../../protocol/modbus_server.dart';
import '../../services/simulation_service.dart';
import '../dialogs/batch_fill_dialog.dart';
import '../dialogs/edit_register_dialog.dart';
import '../dialogs/simulation_config_dialog.dart';

class RegisterViewTab extends StatefulWidget {
  final List<ConnectionConfig> connections;
  final VoidCallback onDataChanged;

  const RegisterViewTab({
    super.key,
    required this.connections,
    required this.onDataChanged,
  });

  @override
  State<RegisterViewTab> createState() => _RegisterViewTabState();
}

class _RegisterViewTabState extends State<RegisterViewTab> {
  ConnectionConfig? _selectedConnection;
  SlaveModel? _selectedSlave;
  RegisterGroupModel? _selectedGroup;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _syncSelection();
    // Listen to simulation updates
    SimulationService.instance.addListener(_onSimTick);
  }

  @override
  void dispose() {
    SimulationService.instance.removeListener(_onSimTick);
    super.dispose();
  }

  void _onSimTick() {
    if (mounted) setState(() {});
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

  List<RegisterModel> _filteredRegisters() {
    if (_selectedGroup == null) return [];
    if (_searchKeyword.isEmpty) return _selectedGroup!.registers;

    final kw = _searchKeyword.toLowerCase();
    return _selectedGroup!.registers.where((r) {
      final addrMatch = r.address.toString().contains(kw) ||
          (_selectedSlave?.formatAddress(r.address, _selectedGroup!.registerType).contains(kw) ?? false);
      final aliasMatch = r.alias?.toLowerCase().contains(kw) ?? false;
      final commentMatch = r.comment?.toLowerCase().contains(kw) ?? false;
      return addrMatch || aliasMatch || commentMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    _syncSelection();

    final isSimRunning = SimulationService.instance.isRunning;
    final isServerRunning = _selectedConnection?.isRunning ?? false;
    final filtered = _filteredRegisters();

    return Scaffold(
      body: Column(
        children: [
          // Top Selectors & Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchBox = SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: i18n.t('searchHint'),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _searchKeyword = v.trim()),
                  ),
                );

                final selectorsAndButtons = <Widget>[
                  // Connection Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButton<ConnectionConfig>(
                      value: widget.connections.contains(_selectedConnection) ? _selectedConnection : null,
                      hint: Text(i18n.t('selectConn')),
                      underline: const SizedBox(),
                      items: widget.connections.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: c.isRunning ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (c) {
                        setState(() {
                          _selectedConnection = c;
                          _selectedSlave = c?.slaves.isNotEmpty == true ? c!.slaves.first : null;
                          _selectedGroup = _selectedSlave?.groups.isNotEmpty == true ? _selectedSlave!.groups.first : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Slave Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButton<SlaveModel>(
                      value: _selectedConnection?.slaves.contains(_selectedSlave) == true ? _selectedSlave : null,
                      hint: Text(i18n.t('selectSlave')),
                      underline: const SizedBox(),
                      items: (_selectedConnection?.slaves ?? []).map((s) {
                        return DropdownMenuItem(
                          value: s,
                          child: Text('${s.name} [ID: ${s.slaveId}]'),
                        );
                      }).toList(),
                      onChanged: (s) {
                        setState(() {
                          _selectedSlave = s;
                          _selectedGroup = s?.groups.isNotEmpty == true ? s!.groups.first : null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Group Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: DropdownButton<RegisterGroupModel>(
                      value: _selectedSlave?.groups.contains(_selectedGroup) == true ? _selectedGroup : null,
                      hint: Text(i18n.t('selectGroup')),
                      underline: const SizedBox(),
                      items: (_selectedSlave?.groups ?? []).map((g) {
                        return DropdownMenuItem(
                          value: g,
                          child: Text('${g.groupName} (${g.quantity} ${AppI18n.instance.t('pointsCount')})'),
                        );
                      }).toList(),
                      onChanged: (g) => setState(() => _selectedGroup = g),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Server Quick Action
                  FilledButton.tonalIcon(
                    icon: Icon(
                      isServerRunning ? Icons.stop : Icons.play_arrow,
                      size: 16,
                      color: isServerRunning ? Colors.red : Colors.green,
                    ),
                    label: Text(isServerRunning ? i18n.t('stopService') : i18n.t('startListen')),
                    onPressed: _selectedConnection == null
                        ? null
                        : () async {
                            if (isServerRunning) {
                              await ModbusServerManager.instance.stopServer(_selectedConnection!);
                            } else {
                              try {
                                await ModbusServerManager.instance.startServer(_selectedConnection!);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${AppI18n.instance.t('startListen')} error: $e')),
                                  );
                                }
                              }
                            }
                            setState(() {});
                            widget.onDataChanged();
                          },
                  ),
                  const SizedBox(width: 8),
                  // Simulation toggle
                  FilledButton.tonalIcon(
                    icon: Icon(
                      isSimRunning ? Icons.waves : Icons.blur_linear,
                      size: 16,
                      color: isSimRunning ? Colors.green : Colors.grey,
                    ),
                    label: Text(isSimRunning ? i18n.t('simRunning') : i18n.t('simStart')),
                    onPressed: () {
                      SimulationService.instance.setConnections(widget.connections);
                      SimulationService.instance.toggle();
                      setState(() {});
                    },
                  ),
                ];

                if (constraints.maxWidth >= 990) {
                  return Row(
                    children: [
                      ...selectorsAndButtons,
                      const Spacer(),
                      searchBox,
                    ],
                  );
                } else {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...selectorsAndButtons,
                      searchBox,
                    ],
                  );
                }
              },
            ),
          ),
          // Group Operations Sub-bar
          if (_selectedGroup != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final leftInfo = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.category, size: 14),
                        label: Text(_selectedGroup!.registerType.label, style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${i18n.t('startAddr')}: ${_selectedSlave?.formatAddress(_selectedGroup!.startAddress, _selectedGroup!.registerType)} | ${i18n.t('pointsCount')}: ${_selectedGroup!.quantity}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                      ),
                    ],
                  );

                  final rightActions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: Text(i18n.t('batchFill')),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => BatchFillDialog(group: _selectedGroup!),
                          );
                          if (ok == true) {
                            setState(() {});
                            widget.onDataChanged();
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.waves, size: 16),
                        label: Text(i18n.t('batchWave')),
                        onPressed: () async {
                          final res = await showDialog<dynamic>(
                            context: context,
                            builder: (_) => SimulationConfigDialog(
                              initialConfig: _selectedGroup!.registers.first.simulation,
                              title: '${i18n.t('batchWave')} (${_selectedGroup!.groupName})',
                            ),
                          );
                          if (res != null) {
                            _selectedGroup!.batchConfigureSimulation(res);
                            setState(() {});
                            widget.onDataChanged();
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: Text(i18n.t('resetAll')),
                        onPressed: () {
                          _selectedGroup!.resetAll();
                          setState(() {});
                          widget.onDataChanged();
                        },
                      ),
                    ],
                  );

                  if (constraints.maxWidth >= 720) {
                    return Row(
                      children: [
                        leftInfo,
                        const Spacer(),
                        rightActions,
                      ],
                    );
                  } else {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        leftInfo,
                        rightActions,
                      ],
                    );
                  }
                },
              ),
            ),
          const Divider(height: 1),
          // Registers Table View
          Expanded(
            child: _selectedGroup == null
                ? Center(child: Text(i18n.t('selectGroup')))
                : filtered.isEmpty
                    ? Center(child: Text(i18n.t('searchHint')))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: MediaQuery.of(context).size.width - 120,
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme.surfaceVariant.withOpacity(0.25),
                              ),
                              headingRowHeight: 40,
                              dataRowMinHeight: 44,
                            dataRowMaxHeight: 44,
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            columns: [
                              DataColumn(label: Text(i18n.t('colAddr'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colAlias'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colValue'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colFormat'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colComposite'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colSim'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colComment'), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text(i18n.t('colAction'), style: const TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: filtered.map((r) {
                              final formattedAddr = _selectedSlave!.formatAddress(
                                r.address,
                                _selectedGroup!.registerType,
                              );
                              final byteOrder = _selectedSlave!.byteOrder;

                              // Neighbor words for composite multi-word values
                              final idx = _selectedGroup!.registers.indexOf(r);
                              List<int>? neighborWords;
                              if (idx >= 0 && idx + 1 < _selectedGroup!.registers.length) {
                                neighborWords = _selectedGroup!.registers
                                    .sublist(idx + 1)
                                    .map((e) => e.rawValue)
                                    .toList();
                              }

                              final dispVal = r.getDisplayValue(byteOrder, neighborWords);

                              return DataRow(
                                cells: [
                                  // Address
                                  DataCell(
                                    Text(
                                      formattedAddr,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                    ),
                                  ),
                                  // Alias
                                  DataCell(
                                    Text(
                                      r.alias ?? '-',
                                      style: TextStyle(color: r.alias != null ? theme.colorScheme.primary : null),
                                    ),
                                  ),
                                  // Value
                                  DataCell(
                                    InkWell(
                                      onDoubleTap: () => _showQuickEditValueDialog(r, formattedAddr, byteOrder, neighborWords),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: theme.dividerColor),
                                        ),
                                        child: Text(
                                          dispVal,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: _selectedGroup!.isBitType
                                                ? (r.rawValue != 0 ? Colors.green : Colors.grey)
                                                : theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Format
                                  DataCell(Text(r.valueFormat.label, style: const TextStyle(fontSize: 12))),
                                  // Composite
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (r.compositeType != 0) ...[
                                          Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: r.compositeType == 1 ? Colors.orange : Colors.purple,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          r.compositeType == 0
                                              ? AppI18n.instance.t('singleWord')
                                              : (r.compositeType == 1 ? AppI18n.instance.t('doubleWord') : AppI18n.instance.t('quadWord')),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Wave Simulation badge
                                  DataCell(
                                    r.simulation.enabled
                                        ? Chip(
                                            avatar: const Icon(Icons.waves, size: 14, color: Colors.green),
                                            label: Text(
                                              r.simulation.waveType.label.split(' ')[0],
                                              style: const TextStyle(fontSize: 11, color: Colors.green),
                                            ),
                                            backgroundColor: Colors.green.withOpacity(0.1),
                                          )
                                        : const Text('-', style: TextStyle(color: Colors.grey)),
                                  ),
                                  // Comment
                                  DataCell(Text(r.comment ?? '-', style: const TextStyle(fontSize: 12))),
                                  // Action
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16),
                                          tooltip: AppI18n.instance.t('configRegTitle'),
                                          onPressed: () async {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => EditRegisterDialog(
                                                register: r,
                                                formattedAddress: formattedAddr,
                                                byteOrder: byteOrder,
                                                neighborWords: neighborWords,
                                              ),
                                            );
                                            if (ok == true) {
                                              setState(() {});
                                              widget.onDataChanged();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.waves,
                                            size: 16,
                                            color: r.simulation.enabled ? Colors.green : null,
                                          ),
                                          tooltip: AppI18n.instance.t('simConfigTitle'),
                                          onPressed: () async {
                                            final sim = await showDialog<dynamic>(
                                              context: context,
                                              builder: (_) => SimulationConfigDialog(
                                                initialConfig: r.simulation,
                                                title: '${AppI18n.instance.t('simConfigTitle')} [$formattedAddr]',
                                              ),
                                            );
                                            if (sim != null) {
                                              r.simulation = sim;
                                              setState(() {});
                                              widget.onDataChanged();
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  void _showQuickEditValueDialog(
    RegisterModel r,
    String formattedAddr,
    ModbusByteOrder byteOrder,
    List<int>? neighborWords,
  ) {
    final controller = TextEditingController(
      text: r.getDisplayValue(byteOrder, neighborWords),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppI18n.instance.t('edit')} [$formattedAddr] ${AppI18n.instance.t('currValue')}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '${AppI18n.instance.t('currValue')} (${r.valueFormat.label})',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            _applyQuickEdit(r, controller.text.trim(), byteOrder, ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppI18n.instance.t('cancel')),
          ),
          FilledButton(
            onPressed: () {
              _applyQuickEdit(r, controller.text.trim(), byteOrder, ctx);
            },
            child: Text(AppI18n.instance.t('save')),
          ),
        ],
      ),
    );
  }

  void _applyQuickEdit(RegisterModel r, String text, ModbusByteOrder byteOrder, BuildContext ctx) {
    final words = r.parseAndSetDisplayValue(text, byteOrder);
    if (words != null) {
      // If composite multi-word, also update neighbor registers in group
      if (words.length > 1 && _selectedGroup != null) {
        final idx = _selectedGroup!.registers.indexOf(r);
        for (int i = 1; i < words.length && (idx + i) < _selectedGroup!.registers.length; i++) {
          _selectedGroup!.registers[idx + i].rawValue = words[i];
        }
      }
      Navigator.of(ctx).pop();
      setState(() {});
      widget.onDataChanged();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('convertFailed'))),
      );
    }
  }
}
