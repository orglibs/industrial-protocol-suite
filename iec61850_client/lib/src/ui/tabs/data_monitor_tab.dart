import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/client_variable_model.dart';
import '../../models/scl_models.dart';
import '../../protocol/iec61850_client_manager.dart';
import '../dialogs/control_operation_dialog.dart';
import '../dialogs/write_variable_dialog.dart';

class DataMonitorTab extends StatefulWidget {
  final Iec61850ClientManager manager;
  final VoidCallback onDataChanged;

  const DataMonitorTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<DataMonitorTab> createState() => _DataMonitorTabState();
}

class _DataMonitorTabState extends State<DataMonitorTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _onlyMonitored = false;
  bool _onlyPolling = false;
  String _fcFilter = 'ALL';
  String _searchText = '';
  bool _isPollingAll = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchText = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _pollAllNow() async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) return;

    setState(() => _isPollingAll = true);
    try {
      final targets = engine.allVariables.where((v) => _onlyMonitored ? v.isMonitored : true).toList();
      await engine.readVariables(targets);
      widget.onDataChanged();
    } finally {
      if (mounted) setState(() => _isPollingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final allVars = engine?.allVariables ?? [];

    final filtered = allVars.where((v) {
      if (_onlyMonitored && !v.isMonitored) return false;
      if (_onlyPolling && !v.isPolling) return false;
      if (_fcFilter != 'ALL' && v.fcCode != _fcFilter) return false;
      if (_searchText.isNotEmpty) {
        return v.reference.toLowerCase().contains(_searchText) ||
            v.shortRef.toLowerCase().contains(_searchText) ||
            v.doName.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: i18n.t('searchVars'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchText.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => _searchCtrl.clear())
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(i18n.t('onlyMonitored')),
                selected: _onlyMonitored,
                onSelected: (val) => setState(() => _onlyMonitored = val),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(i18n.t('onlyPolling')),
                selected: _onlyPolling,
                onSelected: (val) => setState(() => _onlyPolling = val),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _fcFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text(i18n.t('fcAll'))),
                  DropdownMenuItem(value: 'ST', child: Text(i18n.t('fcSt'))),
                  DropdownMenuItem(value: 'MX', child: Text(i18n.t('fcMx'))),
                  DropdownMenuItem(value: 'CO', child: Text(i18n.t('fcCo'))),
                  DropdownMenuItem(value: 'SP', child: Text(i18n.t('fcSp'))),
                  DropdownMenuItem(value: 'CF', child: Text(i18n.t('fcCf'))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _fcFilter = val);
                },
              ),
              const Spacer(),
              // Batch Actions
              FilledButton.icon(
                icon: _isPollingAll
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(i18n.t('pollAll')),
                onPressed: (engine?.isConnected ?? false) && !_isPollingAll ? _pollAllNow : null,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.play_circle_outline, size: 16, color: Colors.green),
                label: Text(i18n.t('startPolling')),
                onPressed: () {
                  for (final v in filtered) {
                    v.isPolling = true;
                  }
                  widget.onDataChanged();
                  setState(() {});
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.pause_circle_outline, size: 16, color: Colors.red),
                label: Text(i18n.t('stopPolling')),
                onPressed: () {
                  for (final v in allVars) {
                    v.isPolling = false;
                  }
                  widget.onDataChanged();
                  setState(() {});
                },
              ),
            ],
          ),
        ),

        // Data Table
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(i18n.t('noMatchingPoints'), style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      horizontalMargin: 16,
                      headingRowHeight: 40,
                      dataRowMinHeight: 42,
                      dataRowMaxHeight: 46,
                      columns: [
                        DataColumn(label: Text(i18n.t('colPin'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colRef'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        const DataColumn(label: Text('FC', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colType'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colLiveAcqVal'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colQuality'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('optTimestamp'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colPoll'), style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text(i18n.t('colAction'), style: const TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: filtered.map((v) {
                        return DataRow(
                          cells: [
                            DataCell(
                              IconButton(
                                icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                color: v.isMonitored ? Colors.amber : null,
                                onPressed: () {
                                  setState(() => v.isMonitored = !v.isMonitored);
                                  widget.onDataChanged();
                                },
                              ),
                            ),
                            DataCell(
                              SelectableText(
                                v.shortRef,
                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              ),
                            ),
                            DataCell(_fcBadge(v.fcCode)),
                            DataCell(Text(v.type.name, style: const TextStyle(fontSize: 12))),
                            DataCell(
                              v.type == IecBasicType.boolean
                                  ? Switch(
                                      value: v.value == true,
                                      onChanged: (val) async {
                                        await engine?.writeVariable(v, val);
                                        setState(() {});
                                        widget.onDataChanged();
                                      },
                                    )
                                  : InkWell(
                                      onTap: () => _openWriteDialog(v),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          v.displayValue,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: v.quality == 0 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  v.qualityString,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: v.quality == 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                v.timestamp.toIso8601String().substring(11, 23),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ),
                            DataCell(
                              Switch(
                                value: v.isPolling,
                                onChanged: (val) {
                                  setState(() => v.isPolling = val);
                                  widget.onDataChanged();
                                },
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.refresh, size: 16),
                                    tooltip: i18n.t('readSingle'),
                                    onPressed: () async {
                                      await engine?.readVariable(v);
                                      setState(() {});
                                      widget.onDataChanged();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    tooltip: i18n.t('writeValueTooltip'),
                                    onPressed: () => _openWriteDialog(v),
                                  ),
                                  if (v.isControllable)
                                    IconButton(
                                      icon: const Icon(Icons.power_settings_new, size: 16, color: Colors.deepOrange),
                                      tooltip: i18n.t('remoteControl'),
                                      onPressed: () => _openControlDialog(v),
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

  void _openWriteDialog(ClientVariableModel v) {
    final engine = widget.manager.activeEngine;
    showDialog(
      context: context,
      builder: (ctx) => WriteVariableDialog(
        variable: v,
        onConfirm: (val) async {
          await engine?.writeVariable(v, val);
          setState(() {});
          widget.onDataChanged();
        },
      ),
    );
  }

  void _openControlDialog(ClientVariableModel v) {
    final engine = widget.manager.activeEngine;
    if (engine == null) return;
    showDialog(
      context: context,
      builder: (ctx) => ControlOperationDialog(
        variable: v,
        onOperate: (variable, val, {bool isSbo = false}) async {
          final res = await engine.operateControl(variable, val, isSbo: isSbo);
          setState(() {});
          widget.onDataChanged();
          return res;
        },
      ),
    );
  }
}
