import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/scl_models.dart';
import '../../models/server_config.dart';
import '../../models/server_variable_model.dart';
import '../../models/simulation_config.dart';
import '../../protocol/iec61850_server_manager.dart';
import '../dialogs/simulation_dialog.dart';
import '../dialogs/write_value_dialog.dart';

class DataMonitorTab extends StatefulWidget {
  final Iec61850ServerManager? manager;
  final List<ServerConfig>? connections;
  final ServerConfig? activeConnection;
  final ValueChanged<ServerConfig>? onConnectionChanged;
  final VoidCallback onDataChanged;

  const DataMonitorTab({
    super.key,
    this.manager,
    this.connections,
    this.activeConnection,
    this.onConnectionChanged,
    required this.onDataChanged,
  });

  @override
  State<DataMonitorTab> createState() => _DataMonitorTabState();
}

class _DataMonitorTabState extends State<DataMonitorTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _onlyMonitored = false;
  bool _onlySimulated = false;
  String _fcFilter = 'ALL';
  String _searchText = '';
  ServerConfig? _selectedConn;

  List<ServerConfig> get _effectiveConnections {
    if (widget.connections != null && widget.connections!.isNotEmpty) {
      return widget.connections!;
    }
    if (widget.activeConnection != null) {
      return [widget.activeConnection!];
    }
    if (widget.manager != null) {
      return [
        ServerConfig(
          id: 'conn-default',
          port: 102,
          manager: widget.manager!,
        ),
      ];
    }
    return [];
  }

  void _syncSelectedConnection() {
    final list = _effectiveConnections;
    if (list.isEmpty) {
      _selectedConn = null;
      return;
    }
    if (widget.activeConnection != null && list.contains(widget.activeConnection)) {
      _selectedConn = widget.activeConnection;
    } else if (_selectedConn == null || !list.contains(_selectedConn)) {
      _selectedConn = list.first;
    }
  }

  Iec61850ServerManager? get _effectiveManager =>
      _selectedConn?.manager ?? widget.activeConnection?.manager ?? widget.manager;

  @override
  void initState() {
    super.initState();
    _syncSelectedConnection();
    _searchCtrl.addListener(() {
      setState(() {
        _searchText = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void didUpdateWidget(covariant DataMonitorTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeConnection != oldWidget.activeConnection ||
        widget.connections != oldWidget.connections) {
      _syncSelectedConnection();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _syncSelectedConnection();

    final manager = _effectiveManager;
    final allVars = manager?.engine.allVariables ?? [];

    final filtered = allVars.where((v) {
      if (_onlyMonitored && !v.isMonitored) return false;
      if (_onlySimulated && !v.simulation.enabled) return false;
      if (_fcFilter != 'ALL' && v.fcCode != _fcFilter) return false;
      if (_searchText.isNotEmpty) {
        return v.reference.toLowerCase().contains(_searchText) ||
            v.shortRef.toLowerCase().contains(_searchText) ||
            v.displayName.toLowerCase().contains(_searchText) ||
            (v.name != null && v.name!.toLowerCase().contains(_searchText)) ||
            v.doName.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar (Requirement 4: Compact query area with hover tooltips and horizontal scroll)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Connection Selector
                Tooltip(
                  message: '${_selectedConn?.displayName ?? i18n.t('selectConn')} (Port: ${_selectedConn?.port ?? ""})',
                  child: Container(
                    width: 195,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButton<ServerConfig>(
                      isExpanded: true,
                      value: _effectiveConnections.contains(_selectedConn) ? _selectedConn : _effectiveConnections.firstOrNull,
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      items: _effectiveConnections.map((c) {
                        return DropdownMenuItem<ServerConfig>(
                          value: c,
                          child: Tooltip(
                            message: '${c.displayName} (${c.port})',
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
                                    '${c.displayName} (${c.port})',
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
                        if (c != null) {
                          setState(() {
                            _selectedConn = c;
                          });
                          widget.onConnectionChanged?.call(c);
                          widget.onDataChanged();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Search Input
                SizedBox(
                  width: 200,
                  height: 32,
                  child: Tooltip(
                    message: i18n.t('searchVars'),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchVars'),
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 14),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(maxWidth: 24, maxHeight: 24),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pinned Filter
                Tooltip(
                  message: i18n.t('onlyMonitored'),
                  child: SizedBox(
                    height: 32,
                    child: FilterChip(
                      label: Text(i18n.t('onlyMonitored'), style: const TextStyle(fontSize: 12)),
                      selected: _onlyMonitored,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onSelected: (val) => setState(() => _onlyMonitored = val),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Simulation Filter
                Tooltip(
                  message: i18n.t('onlySimulated'),
                  child: SizedBox(
                    height: 32,
                    child: FilterChip(
                      label: Text(i18n.t('onlySimulated'), style: const TextStyle(fontSize: 12)),
                      selected: _onlySimulated,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onSelected: (val) => setState(() => _onlySimulated = val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // FC Dropdown Filter
                Tooltip(
                  message: 'FC: $_fcFilter',
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButton<String>(
                      value: _fcFilter,
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                      items: [
                        DropdownMenuItem(value: 'ALL', child: Text(i18n.t('fcAll'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'ST', child: Text(i18n.t('fcSt'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'MX', child: Text(i18n.t('fcMx'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'CO', child: Text(i18n.t('fcCo'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'SP', child: Text(i18n.t('fcSp'), style: const TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'CF', child: Text(i18n.t('fcCf'), style: const TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _fcFilter = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Global Simulation Actions
                Tooltip(
                  message: i18n.t('startAllSim'),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 16, color: Colors.green),
                    label: Text(i18n.t('startAllSim')),
                    onPressed: () {
                      final mgr = _effectiveManager;
                      if (mgr == null) return;
                      for (final v in allVars) {
                        if (v.fc == FunctionalConstraint.mx) {
                          v.simulation.enabled = true;
                          if (v.simulation.waveType == EaseWaveType.none) {
                            v.simulation.waveType = EaseWaveType.sine;
                          }
                        }
                      }
                      mgr.simulationService.start(intervalMs: 1000);
                      widget.onDataChanged();
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('stopAllSim'),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.stop, size: 16, color: Colors.red),
                    label: Text(i18n.t('stopAllSim')),
                    onPressed: () {
                      final mgr = _effectiveManager;
                      if (mgr == null) return;
                      for (final v in allVars) {
                        v.simulation.enabled = false;
                      }
                      mgr.simulationService.stop();
                      widget.onDataChanged();
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Variables Table (Requirement 5: Fixed column widths & hover tooltips)
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(i18n.t('noMatchingVarData'), style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 12,
                      headingRowHeight: 38,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 46,
                      columns: [
                        // Column 0: Pin (55.0)
                        DataColumn(
                          label: SizedBox(
                            width: 55.0,
                            child: Tooltip(
                              message: i18n.t('colPin'),
                              child: Text(
                                i18n.t('colPin'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 1: Ref (240.0)
                        DataColumn(
                          label: SizedBox(
                            width: 240.0,
                            child: Tooltip(
                              message: i18n.t('colRef'),
                              child: Text(
                                i18n.t('colRef'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 2: FC (60.0)
                        const DataColumn(
                          label: SizedBox(
                            width: 60.0,
                            child: Tooltip(
                              message: 'FC',
                              child: Text(
                                'FC',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 3: Type (85.0)
                        DataColumn(
                          label: SizedBox(
                            width: 85.0,
                            child: Tooltip(
                              message: i18n.t('colType'),
                              child: Text(
                                i18n.t('colType'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 4: Val (120.0)
                        DataColumn(
                          label: SizedBox(
                            width: 120.0,
                            child: Tooltip(
                              message: i18n.t('colVal'),
                              child: Text(
                                i18n.t('colVal'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 5: Quality (95.0)
                        DataColumn(
                          label: SizedBox(
                            width: 95.0,
                            child: Tooltip(
                              message: i18n.t('colQuality'),
                              child: Text(
                                i18n.t('colQuality'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 6: Time (110.0)
                        DataColumn(
                          label: SizedBox(
                            width: 110.0,
                            child: Tooltip(
                              message: i18n.t('colTime'),
                              child: Text(
                                i18n.t('colTime'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 7: Sim (120.0)
                        DataColumn(
                          label: SizedBox(
                            width: 120.0,
                            child: Tooltip(
                              message: i18n.t('colSim'),
                              child: Text(
                                i18n.t('colSim'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        // Column 8: Action (100.0)
                        DataColumn(
                          label: SizedBox(
                            width: 100.0,
                            child: Tooltip(
                              message: i18n.t('colAction'),
                              child: Text(
                                i18n.t('colAction'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: filtered.map((v) {
                        return DataRow(
                          cells: [
                            // 0: Pin (55.0)
                            DataCell(
                              SizedBox(
                                width: 55.0,
                                child: IconButton(
                                  icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                  color: v.isMonitored ? Colors.amber : null,
                                  onPressed: () {
                                    setState(() {
                                      v.isMonitored = !v.isMonitored;
                                    });
                                    widget.onDataChanged();
                                  },
                                ),
                              ),
                            ),
                            // 1: Ref (240.0)
                            DataCell(
                              SizedBox(
                                width: 240.0,
                                child: Tooltip(
                                  message: '${v.reference}\n${v.displayName}',
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SelectableText(
                                        v.shortRef,
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                        maxLines: 1,
                                      ),
                                      if (v.name != null || v.nameKey != null)
                                        Text(
                                          v.displayName,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // 2: FC (60.0)
                            DataCell(
                              SizedBox(
                                width: 60.0,
                                child: Tooltip(
                                  message: 'FC: ${v.fcCode}',
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _fcBadge(v.fcCode),
                                  ),
                                ),
                              ),
                            ),
                            // 3: Type (85.0)
                            DataCell(
                              SizedBox(
                                width: 85.0,
                                child: Tooltip(
                                  message: v.type.name,
                                  child: Text(
                                    v.type.name,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            // 4: Val (120.0)
                            DataCell(
                              SizedBox(
                                width: 120.0,
                                child: v.type == IecBasicType.boolean
                                    ? Tooltip(
                                        message: '${v.value}',
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Switch(
                                            value: v.value == true,
                                            onChanged: (val) {
                                              setState(() {
                                                v.value = val;
                                              });
                                              widget.onDataChanged();
                                            },
                                          ),
                                        ),
                                      )
                                    : Tooltip(
                                        message: v.displayValue,
                                        child: InkWell(
                                          onTap: () => _openWriteDialog(v),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              v.displayValue,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // 5: Quality (95.0)
                            DataCell(
                              SizedBox(
                                width: 95.0,
                                child: Tooltip(
                                  message: v.qualityString,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: v.quality == 0 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        v.qualityString,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: v.quality == 0 ? Colors.green : Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 6: Time (110.0)
                            DataCell(
                              SizedBox(
                                width: 110.0,
                                child: Tooltip(
                                  message: v.timestamp.toIso8601String(),
                                  child: Text(
                                    v.timestamp.toIso8601String().substring(11, 23),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            // 7: Sim (120.0)
                            DataCell(
                              SizedBox(
                                width: 120.0,
                                child: Tooltip(
                                  message: v.simulation.enabled
                                      ? '${v.simulation.waveType.name.toUpperCase()} (min: ${v.simulation.min}, max: ${v.simulation.max}, step: ${v.simulation.step})'
                                      : '-',
                                  child: InkWell(
                                    onTap: () => _openSimDialog(v),
                                    child: v.simulation.enabled
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.waves, size: 14, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    v.simulation.waveType.name.toUpperCase(),
                                                    style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Text('-', style: TextStyle(color: Colors.grey)),
                                  ),
                                ),
                              ),
                            ),
                            // 8: Action (100.0)
                            DataCell(
                              SizedBox(
                                width: 100.0,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16),
                                      tooltip: i18n.t('writeValueTooltip'),
                                      onPressed: () => _openWriteDialog(v),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.waves, size: 16),
                                      tooltip: i18n.t('colSim'),
                                      onPressed: () => _openSimDialog(v),
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
        ),
      ],
    );
  }

  Widget _fcBadge(String fc) {
    Color bg = Colors.blueGrey;
    if (fc == 'ST') bg = Colors.green[700]!;
    if (fc == 'MX') bg = Colors.teal[700]!;
    if (fc == 'CO') bg = Colors.deepOrange[700]!;
    if (fc == 'SP') bg = Colors.indigo[700]!;
    if (fc == 'CF') bg = Colors.purple[700]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        fc,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _openWriteDialog(ServerVariableModel v) {
    showDialog(
      context: context,
      builder: (ctx) => WriteValueDialog(
        variable: v,
        onSaved: (variable, val, quality) {
          setState(() {
            variable.value = val;
            variable.quality = quality;
          });
          widget.onDataChanged();
        },
      ),
    );
  }

  void _openSimDialog(ServerVariableModel v) {
    showDialog(
      context: context,
      builder: (ctx) => SimulationDialog(
        variable: v,
        onSaved: (variable) {
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }
}
