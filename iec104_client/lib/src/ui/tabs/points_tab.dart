import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../models/connection_config.dart';
import '../../protocol/asdu.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/edit_station_dialog.dart';
import '../dialogs/add_point_dialog.dart';
import '../dialogs/batch_add_points_dialog.dart';
import '../dialogs/edit_point_dialog.dart';
import '../dialogs/station_import_export_dialog.dart';

class PointsTab extends StatefulWidget {
  final List<Iec104ClientConnectionConfig> connections;
  final Iec104ClientConnectionConfig activeConnection;
  final ValueChanged<Iec104ClientConnectionConfig>? onSelectConnection;
  final VoidCallback? onConfigChanged;
  final Iec104Client? client;

  const PointsTab({
    super.key,
    required this.connections,
    required this.activeConnection,
    this.onSelectConnection,
    this.onConfigChanged,
    this.client,
  });

  @override
  State<PointsTab> createState() => _PointsTabState();
}

class _PointsTabState extends State<PointsTab> {
  int _selectedCa = 1;
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  StreamSubscription<ClientPointModel>? _pointSub;
  StreamSubscription<List<ClientStationModel>>? _stationSub;

  final List<String> _categories = [
    'ALL',
    'M_SP_NA_1 (YX)',
    'M_DP_NA_1 (YX)',
    'M_ME_NC_1 (YC)',
    'M_ME_NA_1 (YC)',
    'M_ME_NB_1 (YC)',
    'M_IT_NA_1 (YM)',
    'M_ST_NA_1 (ST)',
    'M_BO_NA_1 (BO)',
  ];

  Iec104Client get _currentClient => widget.activeConnection.client;

  @override
  void initState() {
    super.initState();
    _initSelection();
    _subscribeClient();
  }

  void _initSelection() {
    final c = _currentClient;
    if (c.stations.isNotEmpty) {
      if (!c.stations.containsKey(_selectedCa)) {
        _selectedCa = c.stations.keys.first;
      }
    }
  }

  void _subscribeClient() {
    _pointSub?.cancel();
    _stationSub?.cancel();

    _pointSub = _currentClient.pointUpdateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _stationSub = _currentClient.stationsStream.listen((stations) {
      if (mounted) {
        setState(() {
          if (!_currentClient.stations.containsKey(_selectedCa)) {
            _selectedCa = _currentClient.stations.keys.firstOrNull ?? 1;
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant PointsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeConnection != widget.activeConnection) {
      _initSelection();
      _subscribeClient();
    }
  }

  @override
  void dispose() {
    _pointSub?.cancel();
    _stationSub?.cancel();
    super.dispose();
  }

  void _openAddStationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddStationDialog(
        client: _currentClient,
        onAdded: (newCa) {
          setState(() => _selectedCa = newCa);
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _openEditStationDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => EditStationDialog(
        client: _currentClient,
        station: station,
        onStationChanged: (newCa) {
          setState(() => _selectedCa = newCa);
          widget.onConfigChanged?.call();
        },
        onStationDeleted: () {
          setState(() {
            _selectedCa = _currentClient.stations.keys.firstOrNull ?? 1;
          });
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _openAddPointDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => AddPointDialog(
        station: station,
        onAdded: (p) {
          setState(() {});
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _openBatchAddPointsDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => BatchAddPointsDialog(
        station: station,
        onGenerated: () {
          setState(() {});
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _openEditPointDialog(ClientStationModel station, ClientPointModel point) {
    showDialog(
      context: context,
      builder: (ctx) => EditPointDialog(
        station: station,
        point: point,
        onUpdated: () {
          setState(() {});
          widget.onConfigChanged?.call();
        },
        onDeleted: () {
          setState(() {});
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _openImportExportDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => StationImportExportDialog(
        client: _currentClient,
        currentStation: station,
        onImported: () {
          setState(() {});
          widget.onConfigChanged?.call();
        },
      ),
    );
  }

  void _confirmClearStation(ClientStationModel station) {
    final i18n = AppI18n.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('clearStationPoints')),
        content: Text(
            '${i18n.t('clearPointsPrompt')}\n[${station.displayName}] (COA: ${station.commonAddress})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.t('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => station.clear());
              widget.onConfigChanged?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${i18n.t('pointsCleared')}: CA=${station.commonAddress}')),
              );
            },
            child: Text(i18n.t('clearConfirm')),
          ),
        ],
      ),
    );
  }

  void _quickRemoteControl(ClientPointModel p) {
    final i18n = AppI18n.instance;
    if (p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1) {
      final currentVal = p.value == true;
      final targetVal = !currentVal;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${i18n.t('singleCommand')} - IOA: ${p.ioa}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${i18n.t('name')}: ${p.displayName}'),
              Text('${i18n.t('currValue')}: ${p.displayValue}'),
              const SizedBox(height: 12),
              Text(
                '${i18n.t('setValue')}: ${targetVal ? "1 (ON)" : "0 (OFF)"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(i18n.t('openPresetOrExecutePrompt')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(i18n.t('cancel')),
            ),
            OutlinedButton(
              onPressed: () {
                _currentClient.sendSingleCommand(
                  ca: p.commonAddress,
                  ioa: p.ioa,
                  value: targetVal,
                  select: true,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${i18n.t('presetSelectedSent')}: IOA=${p.ioa}')),
                );
              },
              child: Text(i18n.t('sendSelect')),
            ),
            ElevatedButton(
              onPressed: () {
                _currentClient.sendSingleCommand(
                  ca: p.commonAddress,
                  ioa: p.ioa,
                  value: targetVal,
                  select: false,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${i18n.t('directExecuteSent')}: IOA=${p.ioa}')),
                );
              },
              child: Text(i18n.t('sendExecute')),
            ),
          ],
        ),
      );
    }
  }

  void _deletePoint(ClientStationModel st, ClientPointModel p) {
    final i18n = AppI18n.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('deletePoint')),
        content: Text('${i18n.t('deletePointPrompt')}\nIOA: ${p.ioa} - ${p.displayName}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(i18n.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              st.removePoint(p.ioa);
              setState(() {});
              widget.onConfigChanged?.call();
              Navigator.pop(ctx);
            },
            child: Text(i18n.t('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final conn = widget.activeConnection;
    final c = _currentClient;

    final availableCas = c.stations.keys.toList()..sort();
    if (availableCas.isNotEmpty && !availableCas.contains(_selectedCa)) {
      _selectedCa = availableCas.first;
    }

    final st = c.getStation(_selectedCa);
    var points = st.pointList;

    // Filter by category
    if (_selectedCategory != 'ALL') {
      points = points.where((p) {
        if (_selectedCategory.contains('M_SP') &&
            (p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1)) {
          return true;
        }
        if (_selectedCategory.contains('M_DP') &&
            (p.typeId == AsduTypeId.mDpNa1 || p.typeId == AsduTypeId.mDpTb1)) {
          return true;
        }
        if (_selectedCategory.contains('M_ME_NC') &&
            (p.typeId == AsduTypeId.mMeNc1 || p.typeId == AsduTypeId.mMeTf1)) {
          return true;
        }
        if (_selectedCategory.contains('M_ME_NA') &&
            (p.typeId == AsduTypeId.mMeNa1 || p.typeId == AsduTypeId.mMeTd1)) {
          return true;
        }
        if (_selectedCategory.contains('M_ME_NB') &&
            (p.typeId == AsduTypeId.mMeNb1 || p.typeId == AsduTypeId.mMeTe1)) {
          return true;
        }
        if (_selectedCategory.contains('M_IT') &&
            (p.typeId == AsduTypeId.mItNa1 || p.typeId == AsduTypeId.mItTb1)) {
          return true;
        }
        if (_selectedCategory.contains('M_ST') &&
            (p.typeId == AsduTypeId.mStNa1 || p.typeId == AsduTypeId.mStTb1)) {
          return true;
        }
        if (_selectedCategory.contains('M_BO') &&
            (p.typeId == AsduTypeId.mBoNa1 || p.typeId == AsduTypeId.mBoTb1)) {
          return true;
        }
        return false;
      }).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      points = points.where((p) =>
          p.ioa.toString().contains(q) ||
          '0x${p.ioa.toRadixString(16).toLowerCase()}'.contains(q) ||
          p.displayName.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Top Toolbar: Compact single row, horizontal scrollable, hover tooltips on all controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. Connection Dropdown (width: 165, height: 32)
                Tooltip(
                  message: '${conn.displayName} (${conn.host}:${conn.port})',
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 165,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(Icons.hub, size: 15, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Iec104ClientConnectionConfig>(
                              isExpanded: true,
                              isDense: true,
                              value: widget.connections.contains(conn)
                                  ? conn
                                  : widget.connections.firstOrNull,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface),
                              items: widget.connections.map((cItem) {
                                final text = '${cItem.displayName} (${cItem.host}:${cItem.port})';
                                return DropdownMenuItem(
                                  value: cItem,
                                  child: Tooltip(
                                    message: text,
                                    waitDuration: const Duration(milliseconds: 150),
                                    child: Text(text,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }).toList(),
                              onChanged: (cItem) {
                                if (cItem != null && cItem != conn) {
                                  widget.onSelectConnection?.call(cItem);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 2. Station Dropdown (width: 145, height: 32)
                Tooltip(
                  message:
                      'CA=$_selectedCa - ${c.stations[_selectedCa]?.displayName ?? "Station"} (${c.stations[_selectedCa]?.points.length ?? 0})',
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 145,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        const Icon(Icons.dns, size: 15, color: Colors.teal),
                        const SizedBox(width: 4),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              isDense: true,
                              value: availableCas.contains(_selectedCa)
                                  ? _selectedCa
                                  : (availableCas.isNotEmpty ? availableCas.first : 1),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface),
                              items: availableCas.map((ca) {
                                final text =
                                    'CA=$ca - ${c.stations[ca]?.displayName ?? "Station"} (${c.stations[ca]?.points.length ?? 0})';
                                return DropdownMenuItem(
                                  value: ca,
                                  child: Tooltip(
                                    message: text,
                                    waitDuration: const Duration(milliseconds: 150),
                                    child: Text(text,
                                        style: const TextStyle(fontSize: 12),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCa = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Station actions
                Tooltip(
                  message: i18n.t('addStation'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 14),
                    label: Text(i18n.t('addStation')),
                    onPressed: _openAddStationDialog,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('editStation'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.settings_outlined, size: 14),
                    label: Text(i18n.t('editStation')),
                    onPressed: () => _openEditStationDialog(st),
                  ),
                ),
                const SizedBox(width: 6),

                // 4. Type Filter Dropdown (width: 115, height: 32)
                Tooltip(
                  message: '${i18n.t('filterType')}: $_selectedCategory',
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 115,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        isDense: true,
                        value: _selectedCategory,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat,
                            child: Tooltip(
                              message: cat,
                              waitDuration: const Duration(milliseconds: 150),
                              child: Text(cat,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 5. Search box (width: 130, height: 32)
                Tooltip(
                  message: i18n.t('searchPoint'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    width: 130,
                    height: 32,
                    child: TextField(
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: i18n.t('searchPoint'),
                        hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
                        prefixIcon: const Icon(Icons.search, size: 15),
                        prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 6. Points Actions
                Tooltip(
                  message: i18n.t('addPoint'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: Text(i18n.t('addPoint')),
                    onPressed: () => _openAddPointDialog(st),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('batchGenerate'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.playlist_add, size: 15),
                    label: Text(i18n.t('batchGenerate')),
                    onPressed: () => _openBatchAddPointsDialog(st),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('importExport'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.import_export, size: 15),
                    label: Text(i18n.t('importExport')),
                    onPressed: () => _openImportExportDialog(st),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('singlePointRefresh'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    icon: const Icon(Icons.refresh, size: 15),
                    label: Text(i18n.t('singlePointRefresh')),
                    onPressed: c.state == ClientConnectionState.active
                        ? () {
                            if (points.isNotEmpty) {
                              c.sendReadCommand(ca: _selectedCa, ioa: points.first.ioa);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('C_RD_NA_1: IOA=${points.first.ioa}')),
                              );
                            }
                          }
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('clearStationPoints'),
                  waitDuration: const Duration(milliseconds: 200),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(fontSize: 12, color: Colors.red),
                    ),
                    icon: const Icon(Icons.clear_all, size: 15, color: Colors.red),
                    label: Text(i18n.t('clearStationPoints'),
                        style: const TextStyle(color: Colors.red)),
                    onPressed: st.points.isNotEmpty ? () => _confirmClearStation(st) : null,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Main Table (Fixed Column Widths, Hover Tooltips on Header & Cells)
        Expanded(
          child: points.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 56, color: theme.colorScheme.outline.withOpacity(0.6)),
                      const SizedBox(height: 12),
                      Text(
                        '${i18n.t('noPointsPrompt')} [CA=$_selectedCa]',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(i18n.t('addPoint')),
                            onPressed: () => _openAddPointDialog(st),
                          ),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.playlist_add),
                            label: Text(i18n.t('batchGenerate')),
                            onPressed: () => _openBatchAddPointsDialog(st),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
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
                            columnSpacing: 14,
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
                                tooltip: i18n.t('filterType'),
                                label: SizedBox(
                                  width: 130,
                                  child: Tooltip(
                                    message: i18n.t('filterType'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('filterType'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 3. Name (width: 190)
                              DataColumn(
                                tooltip: i18n.t('name'),
                                label: SizedBox(
                                  width: 190,
                                  child: Tooltip(
                                    message: i18n.t('name'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('name'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 4. Value (width: 110)
                              DataColumn(
                                tooltip: i18n.t('currValue'),
                                label: SizedBox(
                                  width: 110,
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
                              // 6. Last Update (width: 120)
                              DataColumn(
                                tooltip: i18n.t('lastUpdate'),
                                label: SizedBox(
                                  width: 120,
                                  child: Tooltip(
                                    message: i18n.t('lastUpdate'),
                                    waitDuration: const Duration(milliseconds: 200),
                                    child: Text(
                                      i18n.t('lastUpdate'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              // 7. Operations (width: 160)
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
                              final isSwitch =
                                  p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1;
                              final hexIoa =
                                  '0x${p.ioa.toRadixString(16).padLeft(6, '0').toUpperCase()}';
                              final ioaStr = '${p.ioa} ($hexIoa)';
                              final typeStr = '${p.typeId.nameString} [${p.typeId.id}]';
                              final nameStr = p.displayName;
                              final valStr = p.displayValue;
                              final qualityStr = p.quality?.summary ??
                                  (p.quality?.invalid == true ? i18n.t('invalidQuality') : 'GOOD');
                              final timeStr =
                                  p.lastUpdated.toIso8601String().substring(11, 23);

                              return DataRow(
                                cells: [
                                  // 1. IOA
                                  DataCell(
                                    SizedBox(
                                      width: 110,
                                      child: Tooltip(
                                        message: '${i18n.t('ioa')}: $ioaStr',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          ioaStr,
                                          style: const TextStyle(
                                              fontFamily: 'monospace', fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 2. ASDU Type
                                  DataCell(
                                    SizedBox(
                                      width: 130,
                                      child: Tooltip(
                                        message:
                                            '${p.typeId.nameString} [${p.typeId.id}] - ${p.typeId.description}',
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

                                  // 3. Name (supports reactive i18n and editing)
                                  DataCell(
                                    SizedBox(
                                      width: 190,
                                      child: Tooltip(
                                        message: nameStr,
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: InkWell(
                                          onTap: () => _openEditPointDialog(st, p),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  nameStr,
                                                  style: TextStyle(
                                                    color: theme.colorScheme.onSurface,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(Icons.edit,
                                                  size: 13,
                                                  color: theme.colorScheme.outline.withOpacity(0.6)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 4. Value
                                  DataCell(
                                    SizedBox(
                                      width: 110,
                                      child: Tooltip(
                                        message: '${i18n.t('currValue')}: $valStr',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isSwitch
                                                ? (p.value == true
                                                    ? Colors.green.withOpacity(0.15)
                                                    : Colors.red.withOpacity(0.15))
                                                : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: isSwitch
                                                  ? (p.value == true
                                                      ? Colors.green
                                                      : Colors.red)
                                                  : theme.dividerColor,
                                            ),
                                          ),
                                          child: Text(
                                            valStr,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isSwitch
                                                  ? (p.value == true
                                                      ? Colors.green
                                                      : Colors.red)
                                                  : theme.colorScheme.primary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
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
                                        message: '${i18n.t('qualityFlags')}: $qualityStr',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          qualityStr,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: (p.quality != null && p.quality!.invalid)
                                                ? Colors.red
                                                : theme.colorScheme.outline,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // 6. Last Update
                                  DataCell(
                                    SizedBox(
                                      width: 120,
                                      child: Tooltip(
                                        message:
                                            '${i18n.t('lastUpdate')}: $timeStr | ${i18n.t('refreshCount')}: ${p.updateCount}',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Text(
                                          timeStr,
                                          style: TextStyle(
                                              fontSize: 12, color: theme.colorScheme.outline),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                                          if (isSwitch) ...[
                                            IconButton(
                                              iconSize: 17,
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                              style: IconButton.styleFrom(
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                minimumSize: const Size(26, 26),
                                              ),
                                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                              icon: Icon(Icons.touch_app,
                                                  size: 16, color: theme.colorScheme.primary),
                                              tooltip: i18n.t('singleCommand'),
                                              onPressed: () => _quickRemoteControl(p),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: const Icon(Icons.refresh, size: 16),
                                            tooltip: i18n.t('singlePointRefresh'),
                                            onPressed: c.state == ClientConnectionState.active
                                                ? () {
                                                    c.sendReadCommand(
                                                        ca: _selectedCa, ioa: p.ioa);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                          content:
                                                              Text('C_RD_NA_1: IOA=${p.ioa}')),
                                                    );
                                                  }
                                                : null,
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: const Icon(Icons.edit_outlined, size: 16),
                                            tooltip: i18n.t('editPoint'),
                                            onPressed: () => _openEditPointDialog(st, p),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            iconSize: 17,
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            style: IconButton.styleFrom(
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              minimumSize: const Size(26, 26),
                                            ),
                                            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                            icon: const Icon(Icons.delete_outline,
                                                size: 16, color: Colors.red),
                                            tooltip: i18n.t('deletePoint'),
                                            onPressed: () => _deletePoint(st, p),
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
