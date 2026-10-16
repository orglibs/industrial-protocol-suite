import 'dart:async';
import 'package:flutter/material.dart';
import '../../client/iec104_client.dart';
import '../../client/station_data.dart';
import '../../i18n/app_i18n.dart';
import '../../protocol/asdu.dart';
import '../dialogs/add_station_dialog.dart';
import '../dialogs/edit_station_dialog.dart';
import '../dialogs/add_point_dialog.dart';
import '../dialogs/batch_add_points_dialog.dart';
import '../dialogs/edit_point_dialog.dart';
import '../dialogs/station_import_export_dialog.dart';

class PointsTab extends StatefulWidget {
  final Iec104Client client;

  const PointsTab({super.key, required this.client});

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

  @override
  void initState() {
    super.initState();
    if (widget.client.stations.isNotEmpty) {
      _selectedCa = widget.client.stations.keys.first;
    }

    _pointSub = widget.client.pointUpdateStream.listen((_) {
      if (mounted) setState(() {});
    });

    _stationSub = widget.client.stationsStream.listen((stations) {
      if (mounted) {
        setState(() {
          if (!widget.client.stations.containsKey(_selectedCa)) {
            _selectedCa = widget.client.stations.keys.firstOrNull ?? 1;
          }
        });
      }
    });
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
        client: widget.client,
        onAdded: (newCa) {
          setState(() => _selectedCa = newCa);
        },
      ),
    );
  }

  void _openEditStationDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => EditStationDialog(
        client: widget.client,
        station: station,
        onStationChanged: (newCa) {
          setState(() => _selectedCa = newCa);
        },
        onStationDeleted: () {
          setState(() {
            _selectedCa = widget.client.stations.keys.firstOrNull ?? 1;
          });
        },
      ),
    );
  }

  void _openAddPointDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => AddPointDialog(
        station: station,
        onAdded: (p) => setState(() {}),
      ),
    );
  }

  void _openBatchAddPointsDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => BatchAddPointsDialog(
        station: station,
        onGenerated: () => setState(() {}),
      ),
    );
  }

  void _openEditPointDialog(ClientStationModel station, ClientPointModel point) {
    showDialog(
      context: context,
      builder: (ctx) => EditPointDialog(
        station: station,
        point: point,
        onUpdated: () => setState(() {}),
        onDeleted: () => setState(() {}),
      ),
    );
  }

  void _openImportExportDialog(ClientStationModel station) {
    showDialog(
      context: context,
      builder: (ctx) => StationImportExportDialog(
        client: widget.client,
        currentStation: station,
        onImported: () => setState(() {}),
      ),
    );
  }

  void _confirmClearStation(ClientStationModel station) {
    final i18n = AppI18n.instance;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.t('clearStationPoints')),
        content: Text('${i18n.t('clearPointsPrompt')}\n[${station.name}] (COA: ${station.commonAddress})'),
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
              Text('${i18n.t('name')}: ${p.name}'),
              Text('${i18n.t('val')}: ${p.displayValue}'),
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
                widget.client.sendSingleCommand(
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
                widget.client.sendSingleCommand(
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppI18n.instance;
    final c = widget.client;
    final availableCas = c.stations.keys.toList()..sort();
    if (availableCas.isNotEmpty && !availableCas.contains(_selectedCa)) {
      _selectedCa = availableCas.first;
    }

    final st = c.getStation(_selectedCa);
    var points = st.pointList;

    // Filter by category
    if (_selectedCategory != 'ALL') {
      points = points.where((p) {
        if (_selectedCategory.contains('M_SP') && (p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1)) return true;
        if (_selectedCategory.contains('M_DP') && (p.typeId == AsduTypeId.mDpNa1 || p.typeId == AsduTypeId.mDpTb1)) return true;
        if (_selectedCategory.contains('M_ME_NC') && (p.typeId == AsduTypeId.mMeNc1 || p.typeId == AsduTypeId.mMeTf1)) return true;
        if (_selectedCategory.contains('M_ME_NA') && (p.typeId == AsduTypeId.mMeNa1 || p.typeId == AsduTypeId.mMeTd1)) return true;
        if (_selectedCategory.contains('M_ME_NB') && (p.typeId == AsduTypeId.mMeNb1 || p.typeId == AsduTypeId.mMeTe1)) return true;
        if (_selectedCategory.contains('M_IT') && (p.typeId == AsduTypeId.mItNa1 || p.typeId == AsduTypeId.mItTb1)) return true;
        if (_selectedCategory.contains('M_ST') && (p.typeId == AsduTypeId.mStNa1 || p.typeId == AsduTypeId.mStTb1)) return true;
        if (_selectedCategory.contains('M_BO') && (p.typeId == AsduTypeId.mBoNa1 || p.typeId == AsduTypeId.mBoTb1)) return true;
        return false;
      }).toList();
    }

    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      points = points.where((p) =>
          p.ioa.toString().contains(q) ||
          '0x${p.ioa.toRadixString(16).toLowerCase()}'.contains(q) ||
          p.name.toLowerCase().contains(q)).toList();
    }

    return Column(
      children: [
        // Top Toolbar: Station Management & Actions
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Station selector
              Text('${i18n.t('filterStation')}:', style: const TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<int>(
                  value: availableCas.contains(_selectedCa) ? _selectedCa : (availableCas.isNotEmpty ? availableCas.first : 1),
                  underline: const SizedBox(),
                  items: availableCas.map((ca) {
                    return DropdownMenuItem(
                      value: ca,
                      child: Text('CA=$ca - ${c.stations[ca]?.name ?? "Station"} (${c.stations[ca]?.points.length ?? 0})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCa = val);
                  },
                ),
              ),

              // Station action buttons
              OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: Text(i18n.t('addStation')),
                onPressed: _openAddStationDialog,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: Text(i18n.t('editStation')),
                onPressed: () => _openEditStationDialog(st),
              ),

              const SizedBox(width: 8),
              // Points actions
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(i18n.t('addPoint')),
                onPressed: () => _openAddPointDialog(st),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.playlist_add, size: 16),
                label: Text(i18n.t('batchGenerate')),
                onPressed: () => _openBatchAddPointsDialog(st),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.import_export, size: 16),
                label: Text(i18n.t('importExport')),
                onPressed: () => _openImportExportDialog(st),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                label: Text(i18n.t('clearStationPoints'), style: const TextStyle(color: Colors.red)),
                onPressed: st.points.isNotEmpty ? () => _confirmClearStation(st) : null,
              ),
            ],
          ),
        ),

        // Filter & Search toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Category filter
              Text('${i18n.t('filterType')}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  underline: const SizedBox(),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Search
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: i18n.t('searchPoint'),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
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
            ],
          ),
        ),

        // Data Table / List
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
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
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
              : ListView.separated(
                  itemCount: points.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final p = points[idx];
                    final isSwitch = p.typeId == AsduTypeId.mSpNa1 || p.typeId == AsduTypeId.mSpTb1;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: isSwitch
                            ? (p.value == true ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
                            : theme.colorScheme.primaryContainer.withAlpha(80),
                        child: Text(
                          isSwitch ? (p.value == true ? 'ON' : 'OFF') : 'AI',
                          style: TextStyle(
                            color: isSwitch
                                ? (p.value == true ? Colors.green : Colors.red)
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'IOA: ${p.ioa}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(
                            '[${p.typeId.name}]',
                            style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          Text('${i18n.t('lastUpdate')}: ${p.lastUpdated.toIso8601String().substring(11, 23)}'),
                          const SizedBox(width: 12),
                          Text('${i18n.t('refreshCount')}: ${p.updateCount}'),
                          if (p.quality != null && p.quality!.invalid) ...[
                            const SizedBox(width: 8),
                            Text(i18n.t('invalidQuality'), style: const TextStyle(color: Colors.red)),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                              border: Border.all(color: theme.dividerColor),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.displayValue,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSwitch
                                    ? (p.value == true ? Colors.green : Colors.red)
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          if (isSwitch) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.touch_app, color: theme.colorScheme.primary),
                              tooltip: i18n.t('singleCommand'),
                              onPressed: () => _quickRemoteControl(p),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            tooltip: i18n.t('singlePointRefresh'),
                            onPressed: c.state == ClientConnectionState.active
                                ? () {
                                    c.sendReadCommand(ca: _selectedCa, ioa: p.ioa);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('C_RD_NA_1: IOA=${p.ioa}')),
                                    );
                                  }
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: i18n.t('editPoint'),
                            onPressed: () => _openEditPointDialog(st, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
