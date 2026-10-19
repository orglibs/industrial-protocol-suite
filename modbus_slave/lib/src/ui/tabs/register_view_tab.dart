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
      final aliasMatch = (r.displayAlias ?? r.alias)?.toLowerCase().contains(kw) ?? false;
      final commentMatch = (r.displayComment ?? r.comment)?.toLowerCase().contains(kw) ?? false;
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Connection Dropdown (width: 195, menuWidth: 320)
                  Tooltip(
                    message: _selectedConnection?.displayName ?? i18n.t('selectConn'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 195,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButton<ConnectionConfig>(
                        isExpanded: true,
                        menuWidth: 320,
                        menuMaxHeight: 400,
                        value: widget.connections.contains(_selectedConnection) ? _selectedConnection : null,
                        hint: Text(i18n.t('selectConn'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: widget.connections.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Tooltip(
                              message: c.displayName,
                              waitDuration: const Duration(milliseconds: 150),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: c.isRunning ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      c.displayName,
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                  ),
                  const SizedBox(width: 8),
                  // Slave Dropdown (width: 175, menuWidth: 280)
                  Tooltip(
                    message: _selectedSlave != null
                        ? '${_selectedSlave!.displayName} [ID: ${_selectedSlave!.slaveId}]'
                        : i18n.t('selectSlave'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 175,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButton<SlaveModel>(
                        isExpanded: true,
                        menuWidth: 280,
                        menuMaxHeight: 400,
                        value: _selectedConnection?.slaves.contains(_selectedSlave) == true ? _selectedSlave : null,
                        hint: Text(i18n.t('selectSlave'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: (_selectedConnection?.slaves ?? []).map((s) {
                          final text = '${s.displayName} [ID: ${s.slaveId}]';
                          return DropdownMenuItem(
                            value: s,
                            child: Tooltip(
                              message: text,
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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
                  ),
                  const SizedBox(width: 8),
                  // Group Dropdown (width: 230, menuWidth: 360)
                  Tooltip(
                    message: _selectedGroup != null
                        ? '${_selectedGroup!.displayGroupName} (${_selectedGroup!.quantity} ${AppI18n.instance.t('pointsCount')})'
                        : i18n.t('selectGroup'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 230,
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      alignment: Alignment.center,
                      child: DropdownButton<RegisterGroupModel>(
                        isExpanded: true,
                        menuWidth: 360,
                        menuMaxHeight: 400,
                        value: _selectedSlave?.groups.contains(_selectedGroup) == true ? _selectedGroup : null,
                        hint: Text(i18n.t('selectGroup'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: (_selectedSlave?.groups ?? []).map((g) {
                          final text = '${g.displayGroupName} (${g.quantity} ${AppI18n.instance.t('pointsCount')})';
                          return DropdownMenuItem(
                            value: g,
                            child: Tooltip(
                              message: text,
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(
                                text,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (g) => setState(() => _selectedGroup = g),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Server Quick Action
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 32),
                      maximumSize: const Size(double.infinity, 32),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 32),
                      maximumSize: const Size(double.infinity, 32),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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
                  const SizedBox(width: 8),
                  // Search box (width: 170)
                  SizedBox(
                    width: 170,
                    height: 32,
                    child: TextField(
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchHint'),
                        hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (v) => setState(() => _searchKeyword = v.trim()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Group Operations Sub-bar
          if (_selectedGroup != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.surfaceVariant.withOpacity(0.15),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      avatar: const Icon(Icons.category, size: 13),
                      label: Text(_selectedGroup!.registerType.label, style: const TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${i18n.t('startAddr')}: ${_selectedSlave?.formatAddress(_selectedGroup!.startAddress, _selectedGroup!.registerType)} | ${i18n.t('pointsCount')}: ${_selectedGroup!.quantity}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.auto_fix_high, size: 14),
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
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.waves, size: 14),
                      label: Text(i18n.t('batchWave')),
                      onPressed: () async {
                        final res = await showDialog<dynamic>(
                          context: context,
                          builder: (_) => SimulationConfigDialog(
                            initialConfig: _selectedGroup!.registers.first.simulation,
                            title: '${i18n.t('batchWave')} (${_selectedGroup!.displayGroupName})',
                          ),
                        );
                        if (res != null) {
                          _selectedGroup!.batchConfigureSimulation(res);
                          setState(() {});
                          widget.onDataChanged();
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        minimumSize: const Size(0, 28),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.restart_alt, size: 14),
                      label: Text(i18n.t('resetAll')),
                      onPressed: () {
                        _selectedGroup!.resetAll();
                        setState(() {});
                        widget.onDataChanged();
                      },
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          // Registers Table View
          Expanded(
            child: _selectedGroup == null
                ? Center(child: Text(i18n.t('selectGroup')))
                : filtered.isEmpty
                    ? Center(child: Text(i18n.t('searchHint')))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(12),
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth - 24,
                                ),
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    theme.colorScheme.surfaceVariant.withOpacity(0.25),
                                  ),
                                  headingRowHeight: 38,
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 40,
                                  horizontalMargin: 12,
                                  columnSpacing: 16,
                                  columns: [
                                    DataColumn(
                                      tooltip: i18n.t('colAddr'),
                                      label: SizedBox(
                                        width: 75,
                                        child: Tooltip(
                                          message: i18n.t('colAddr'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colAddr'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colAlias'),
                                      label: SizedBox(
                                        width: 200,
                                        child: Tooltip(
                                          message: i18n.t('colAlias'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colAlias'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colValue'),
                                      label: SizedBox(
                                        width: 120,
                                        child: Tooltip(
                                          message: i18n.t('colValue'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colValue'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colFormat'),
                                      label: SizedBox(
                                        width: 100,
                                        child: Tooltip(
                                          message: i18n.t('colFormat'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colFormat'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colComposite'),
                                      label: SizedBox(
                                        width: 90,
                                        child: Tooltip(
                                          message: i18n.t('colComposite'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colComposite'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colSim'),
                                      label: SizedBox(
                                        width: 110,
                                        child: Tooltip(
                                          message: i18n.t('colSim'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colSim'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colComment'),
                                      label: SizedBox(
                                        width: 200,
                                        child: Tooltip(
                                          message: i18n.t('colComment'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colComment'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      tooltip: i18n.t('colAction'),
                                      label: SizedBox(
                                        width: 75,
                                        child: Tooltip(
                                          message: i18n.t('colAction'),
                                          waitDuration: const Duration(milliseconds: 200),
                                          child: Text(
                                            i18n.t('colAction'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
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

                                    final compositeLabel = r.compositeType == 0
                                        ? AppI18n.instance.t('singleWord')
                                        : (r.compositeType == 1
                                            ? AppI18n.instance.t('doubleWord')
                                            : AppI18n.instance.t('quadWord'));

                                    final simLabel = r.simulation.enabled
                                        ? '${r.simulation.waveType.label} (${r.simulation.min}..${r.simulation.max}, ${r.simulation.durationMs}ms)'
                                        : '-';

                                    return DataRow(
                                      cells: [
                                        // 1. Address
                                        DataCell(
                                          SizedBox(
                                            width: 75,
                                            child: Tooltip(
                                              message: formattedAddr,
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: Directionality(
                                                textDirection: TextDirection.ltr,
                                                child: Text(
                                                  formattedAddr,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'monospace',
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 2. Alias
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Tooltip(
                                              message: r.displayAlias ?? '-',
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: Text(
                                                r.displayAlias ?? '-',
                                                style: TextStyle(
                                                  color: r.displayAlias != null ? theme.colorScheme.primary : null,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 3. Value
                                        DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Tooltip(
                                              message: dispVal,
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: InkWell(
                                                onDoubleTap: () => _showQuickEditValueDialog(
                                                    r, formattedAddr, byteOrder, neighborWords),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: theme.dividerColor),
                                                  ),
                                                  child: Directionality(
                                                    textDirection: TextDirection.ltr,
                                                    child: Text(
                                                      dispVal,
                                                      style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                        color: _selectedGroup!.isBitType
                                                            ? (r.rawValue != 0 ? Colors.green : Colors.grey)
                                                            : theme.colorScheme.primary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 4. Format
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Tooltip(
                                              message: r.valueFormat.label,
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: Text(
                                                r.valueFormat.label,
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 5. Composite
                                        DataCell(
                                          SizedBox(
                                            width: 90,
                                            child: Tooltip(
                                              message: compositeLabel,
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: Row(
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
                                                  Expanded(
                                                    child: Text(
                                                      compositeLabel,
                                                      style: const TextStyle(fontSize: 12),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 6. Wave Simulation badge
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Tooltip(
                                              message: simLabel,
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: r.simulation.enabled
                                                  ? Chip(
                                                      visualDensity: VisualDensity.compact,
                                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                                      avatar: const Icon(Icons.waves, size: 14, color: Colors.green),
                                                      label: Text(
                                                        r.simulation.waveType.shortLabel,
                                                        style: const TextStyle(fontSize: 11, color: Colors.green),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      backgroundColor: Colors.green.withOpacity(0.1),
                                                    )
                                                  : const Text('-', style: TextStyle(color: Colors.grey)),
                                            ),
                                          ),
                                        ),
                                        // 7. Comment
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Tooltip(
                                              message: r.displayComment ?? '-',
                                              waitDuration: const Duration(milliseconds: 200),
                                              child: Text(
                                                r.displayComment ?? '-',
                                                style: const TextStyle(fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // 8. Action
                                        DataCell(
                                          SizedBox(
                                            width: 75,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, size: 16),
                                                  tooltip: AppI18n.instance.t('configRegTitle'),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                  onPressed: () async {
                                                    final sim = await showDialog<dynamic>(
                                                      context: context,
                                                      builder: (_) => SimulationConfigDialog(
                                                        initialConfig: r.simulation,
                                                        title:
                                                            '${AppI18n.instance.t('simConfigTitle')} [$formattedAddr]',
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
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                        ),
                      ),
                    );
                  },
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
