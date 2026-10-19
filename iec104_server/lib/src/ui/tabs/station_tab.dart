import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../protocol/asdu.dart';
import '../../server/iec104_server.dart';
import '../../server/station.dart';
import '../dialogs/add_point_dialog.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/batch_init_dialog.dart';
import '../dialogs/edit_station_dialog.dart';
import '../dialogs/point_edit_value_dialog.dart';

class StationTab extends StatefulWidget {
  final List<Iec104ConnectionConfig>? connections;
  final Iec104Server? server;
  final VoidCallback? onDataChanged;

  const StationTab({
    super.key,
    this.connections,
    this.server,
    this.onDataChanged,
  });

  @override
  State<StationTab> createState() => _StationTabState();
}

class _StationTabState extends State<StationTab> {
  Iec104ConnectionConfig? _selectedConnection;
  int _selectedCoa = 1;
  String _filterType = 'ALL';
  String _searchQuery = '';

  // Fallback connection list when widget.server is passed directly
  late List<Iec104ConnectionConfig> _internalConnections;

  @override
  void initState() {
    super.initState();
    _initConnections();
    _syncSelection();
    _listenToUpdates();
  }

  @override
  void didUpdateWidget(covariant StationTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connections != oldWidget.connections || widget.server != oldWidget.server) {
      _initConnections();
      _syncSelection();
    }
  }

  void _initConnections() {
    if (widget.connections != null && widget.connections!.isNotEmpty) {
      _internalConnections = widget.connections!;
    } else if (widget.server != null) {
      _internalConnections = [
        Iec104ConnectionConfig(
          id: 'conn-server',
          name: 'IEC 104 Server',
          host: widget.server!.host,
          port: widget.server!.port,
          server: widget.server!,
        ),
      ];
    } else {
      _internalConnections = [];
    }
  }

  void _syncSelection() {
    if (_internalConnections.isNotEmpty) {
      if (_selectedConnection == null || !_internalConnections.contains(_selectedConnection)) {
        _selectedConnection = _internalConnections.first;
      }
      final stations = _selectedConnection?.server.stations ?? {};
      if (stations.isNotEmpty) {
        if (!stations.containsKey(_selectedCoa)) {
          _selectedCoa = stations.keys.first;
        }
      } else {
        _selectedCoa = 1;
      }
    } else {
      _selectedConnection = null;
      _selectedCoa = 1;
    }
  }

  void _listenToUpdates() {
    for (final conn in _internalConnections) {
      conn.server.pointUpdateStream.listen((_) {
        if (mounted) setState(() {});
      });
      conn.server.stationsStream.listen((_) {
        if (mounted) {
          setState(() {
            _syncSelection();
          });
        }
      });
    }
  }

  Station? get _currentStation {
    final server = _selectedConnection?.server ?? widget.server;
    return server?.stations[_selectedCoa];
  }

  Iec104Server? get _currentServer => _selectedConnection?.server ?? widget.server;

  List<StationPoint> get _filteredPoints {
    final station = _currentStation;
    if (station == null) return [];

    return station.pointList.where((p) {
      // Type filter
      if (_filterType == 'SP') {
        if (p.typeId != AsduTypeId.mSpNa1 && p.typeId != AsduTypeId.mSpTb1) return false;
      } else if (_filterType == 'DP') {
        if (p.typeId != AsduTypeId.mDpNa1 && p.typeId != AsduTypeId.mDpTb1) return false;
      } else if (_filterType == 'ME') {
        if (p.typeId != AsduTypeId.mMeNa1 &&
            p.typeId != AsduTypeId.mMeNb1 &&
            p.typeId != AsduTypeId.mMeNc1 &&
            p.typeId != AsduTypeId.mMeTd1 &&
            p.typeId != AsduTypeId.mMeTe1 &&
            p.typeId != AsduTypeId.mMeTf1) {
          return false;
        }
      } else if (_filterType == 'IT') {
        if (p.typeId != AsduTypeId.mItNa1 && p.typeId != AsduTypeId.mItTb1) return false;
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchIoa = p.ioa.toString().contains(q) ||
            '0x${p.ioa.toRadixString(16).toLowerCase()}'.contains(q);
        final matchName = p.displayName.toLowerCase().contains(q) || p.name.toLowerCase().contains(q);
        if (!matchIoa && !matchName) return false;
      }

      return true;
    }).toList();
  }

  void _showEditDialog(StationPoint point) {
    final server = _currentServer;
    if (server == null) return;

    showDialog(
      context: context,
      builder: (context) => PointEditValueDialog(
        point: point,
        onSave: (newVal, quality) {
          server.updatePointValue(
            _selectedCoa,
            point.ioa,
            newVal,
            quality: quality,
            triggerSpontaneous: true,
          );
          widget.onDataChanged?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('[IOA: ${point.ioa}] $newVal (COT=3)'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    _syncSelection();

    final station = _currentStation;
    final server = _currentServer;
    final points = _filteredPoints;

    return Column(
      children: [
        // Top compact Query & Operation Bar (Requirement 4: Compact query area with hover tooltips)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Connection Dropdown (width: 195, height: 32)
                if (_internalConnections.length > 1 || widget.connections != null) ...[
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
                      child: DropdownButton<Iec104ConnectionConfig>(
                        isExpanded: true,
                        menuWidth: 320,
                        menuMaxHeight: 400,
                        value: _internalConnections.contains(_selectedConnection) ? _selectedConnection : null,
                        hint: Text(i18n.t('selectConn'), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                        underline: const SizedBox(),
                        isDense: true,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: _internalConnections.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Tooltip(
                              message: '${c.displayName} (${c.host}:${c.port})',
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
                          if (c != null) {
                            setState(() {
                              _selectedConnection = c;
                              final stKeys = c.server.stations.keys;
                              _selectedCoa = stKeys.isNotEmpty ? stKeys.first : 1;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 2. Station Dropdown (width: 180, height: 32)
                Tooltip(
                  message: station != null
                      ? 'CA: ${station.commonAddress} - ${station.displayName} (${station.points.length})'
                      : i18n.t('selectSlave'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 180,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButton<int>(
                      isExpanded: true,
                      menuWidth: 280,
                      menuMaxHeight: 400,
                      value: (server != null && server.stations.containsKey(_selectedCoa))
                          ? _selectedCoa
                          : (server?.stations.keys.firstOrNull ?? 1),
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      items: (server?.stations.values ?? []).map((s) {
                        final label = 'CA: ${s.commonAddress} - ${s.displayName} (${s.points.length})';
                        return DropdownMenuItem(
                          value: s.commonAddress,
                          child: Tooltip(
                            message: label,
                            waitDuration: const Duration(milliseconds: 150),
                            child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedCoa = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Station actions (Add / Edit)
                Tooltip(
                  message: i18n.t('addStation'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 15),
                    label: Text(i18n.t('addStation')),
                    onPressed: server == null
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AddStationDialog(
                                connection: _selectedConnection,
                                server: server,
                                onAdded: (newCa) {
                                  setState(() => _selectedCoa = newCa);
                                  widget.onDataChanged?.call();
                                },
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 6),
                if (station != null) ...[
                  Tooltip(
                    message: i18n.t('editStation'),
                    waitDuration: const Duration(milliseconds: 300),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      icon: const Icon(Icons.settings_outlined, size: 15),
                      label: Text(i18n.t('editStation')),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => EditStationDialog(
                            connection: _selectedConnection,
                            server: server,
                            station: station,
                            onStationChanged: (newCa) {
                              setState(() => _selectedCoa = newCa);
                              widget.onDataChanged?.call();
                            },
                            onStationDeleted: () {
                              setState(() {
                                _selectedCoa = server?.stations.keys.firstOrNull ?? 1;
                              });
                              widget.onDataChanged?.call();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // 4. Type Filter Dropdown (width: 140, height: 32)
                Tooltip(
                  message: '${i18n.t('colFormat')}: $_filterType',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Container(
                    width: 140,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _filterType,
                      underline: const SizedBox(),
                      isDense: true,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      items: [
                        DropdownMenuItem(value: 'ALL', child: Text(i18n.t('allTypes'), style: const TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'SP', child: Text('SP (Type 1/30)', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'DP', child: Text('DP (Type 3/31)', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'ME', child: Text('ME (Type 9/11/13)', style: TextStyle(fontSize: 12))),
                        const DropdownMenuItem(value: 'IT', child: Text('IT (Type 15/37)', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _filterType = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 5. Search box (width: 160, height: 32)
                Tooltip(
                  message: i18n.t('searchHint'),
                  waitDuration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    width: 160,
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
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 6. Action buttons (Add Point, Batch Init, Reset Demo)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(i18n.t('addPoint')),
                  onPressed: station == null
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => AddPointDialog(
                              station: station,
                              onAdd: (newPoint) {
                                setState(() => station.addPoint(newPoint));
                                widget.onDataChanged?.call();
                              },
                            ),
                          );
                        },
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.playlist_add, size: 16),
                  label: Text(i18n.t('batchInit')),
                  onPressed: station == null
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => BatchInitDialog(
                              station: station,
                              onGenerate: ({required count, required prefix, required startIoa, required typeId}) {
                                setState(() {
                                  station.batchGeneratePoints(
                                    typeId: typeId,
                                    startIoa: startIoa,
                                    count: count,
                                    prefix: prefix,
                                  );
                                });
                                widget.onDataChanged?.call();
                              },
                            ),
                          );
                        },
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(i18n.t('resetAll')),
                  onPressed: server == null
                      ? null
                      : () {
                          setState(() {
                            server.stations[_selectedCoa] = Station.createDefault(
                              commonAddress: _selectedCoa,
                              name: station?.name ?? 'Substation #1',
                              nameKey: station?.nameKey,
                            );
                          });
                          widget.onDataChanged?.call();
                        },
                ),
              ],
            ),
          ),
        ),

        // Data Table View (Requirement 5: Fixed column widths & hover tooltips)
        Expanded(
          child: points.isEmpty
              ? Center(child: Text(i18n.t('noChartData')))
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
                              // 1. IOA (width: 110)
                              DataColumn(
                                tooltip: i18n.t('ioa'),
                                label: SizedBox(
                                  width: 110,
                                  child: Tooltip(
                                    message: i18n.t('ioa'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('ioa'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 2. ASDU Type (width: 130)
                              DataColumn(
                                tooltip: 'ASDU Type',
                                label: const SizedBox(
                                  width: 130,
                                  child: Tooltip(
                                    message: 'ASDU Type',
                                    waitDuration: Duration(milliseconds: 200),
                                    child: Text(
                                      'ASDU Type',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 3. Name (width: 220)
                              DataColumn(
                                tooltip: i18n.t('pointName'),
                                label: SizedBox(
                                  width: 220,
                                  child: Tooltip(
                                    message: i18n.t('pointName'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('pointName'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 4. Value (width: 120)
                              DataColumn(
                                tooltip: i18n.t('currValue'),
                                label: SizedBox(
                                  width: 120,
                                  child: Tooltip(
                                    message: i18n.t('currValue'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('currValue'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 5. Quality (width: 100)
                              DataColumn(
                                tooltip: i18n.t('qualityFlags'),
                                label: SizedBox(
                                  width: 100,
                                  child: Tooltip(
                                    message: i18n.t('qualityFlags'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('qualityFlags'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 6. Simulation (width: 130)
                              DataColumn(
                                tooltip: i18n.t('colSim'),
                                label: SizedBox(
                                  width: 130,
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
                              // 7. Operations (width: 150)
                                DataColumn(
                                tooltip: i18n.t('operation'),
                                label: SizedBox(
                                  width: 160,
                                  child: Tooltip(
                                    message: i18n.t('operation'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('operation'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: points.map((p) {
                              final isSingle = p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1;
                              final hexIoa = '0x${p.ioa.toRadixString(16).padLeft(6, '0').toUpperCase()}';
                              final ioaStr = '${p.ioa} ($hexIoa)';
                              final typeStr = '${p.typeId.nameString} [${p.typeId.id}]';
                              final nameStr = p.displayName;
                              final valStr = p.displayValue;
                              final qualityStr = p.quality.summary;
                              final simStr = p.autoChangeEnabled ? '${p.easeType.description} (${i18n.t("active")})' : '-';

                              return DataRow(
                                cells: [
                                  // 1. IOA
                                  DataCell(
                                    SizedBox(
                                      width: 110,
                                      child: Tooltip(
                                        message: ioaStr,
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          ioaStr,
                                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 2. Type
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Tooltip(
                                        message: '${p.typeId.nameString} [${p.typeId.id}] - ${p.typeId.description}',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          typeStr,
                                          style: const TextStyle(fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 3. Name (supports multi-language)
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Tooltip(
                                        message: nameStr,
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          nameStr,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 4. Value (Click to edit)
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: Tooltip(
                                        message: '$valStr (${i18n.t('clickToModify')})',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: InkWell(
                                          onTap: () => _showEditDialog(p),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: theme.dividerColor),
                                            ),
                                            child: Text(
                                              valStr,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isSingle
                                                    ? (p.value == true ? Colors.green : Colors.grey)
                                                    : theme.colorScheme.primary,
                                                fontFamily: 'monospace',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 5. Quality
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: Tooltip(
                                        message: qualityStr,
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (p.quality.invalid ? Colors.red : Colors.green).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: (p.quality.invalid ? Colors.red : Colors.green).withOpacity(0.4),
                                            ),
                                          ),
                                          child: Text(
                                            qualityStr,
                                            style: TextStyle(
                                              color: p.quality.invalid ? Colors.redAccent : Colors.green,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 6. Simulation
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Tooltip(
                                        message: simStr,
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Switch(
                                              value: p.autoChangeEnabled,
                                              onChanged: (v) {
                                                setState(() => p.autoChangeEnabled = v);
                                                widget.onDataChanged?.call();
                                              },
                                            ),
                                            if (p.autoChangeEnabled)
                                              Flexible(
                                                child: Text(
                                                  p.easeType.description,
                                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 7. Operations
                                  DataCell(
                                    SizedBox(
                                      width: 160,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSingle)
                                            IconButton(
                                              iconSize: 18,
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              style: IconButton.styleFrom(
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: const Size(26, 26),
                                              ),
                                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                              icon: Icon(p.value == true ? Icons.toggle_on : Icons.toggle_off,
                                                  color: p.value == true ? Colors.green : Colors.grey),
                                              tooltip: 'Toggle',
                                              onPressed: server == null
                                                  ? null
                                                  : () {
                                                      server.updatePointValue(
                                                        _selectedCoa,
                                                        p.ioa,
                                                        !(p.value == true),
                                                        triggerSpontaneous: true,
                                                      );
                                                      widget.onDataChanged?.call();
                                                    },
                                            ),
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: Icon(Icons.send, color: theme.colorScheme.primary),
                                            tooltip: 'Spontaneous (COT=3)',
                                            onPressed: server == null
                                                ? null
                                                : () {
                                                    server.broadcastSpontaneous(p, _selectedCoa);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('[COT=3] ${p.displayName}'),
                                                        duration: const Duration(seconds: 1),
                                                      ),
                                                    );
                                                  },
                                          ),
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: const Icon(Icons.edit, color: Colors.grey),
                                            tooltip: i18n.t('editPoint'),
                                            onPressed: () => _showEditDialog(p),
                                          ),
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            tooltip: i18n.t('deletePoint'),
                                            onPressed: () {
                                              setState(() => station?.removePoint(p.ioa));
                                              widget.onDataChanged?.call();
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
    );
  }
}
