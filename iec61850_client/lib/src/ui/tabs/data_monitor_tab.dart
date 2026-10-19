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
            v.displayName.toLowerCase().contains(_searchText) ||
            (v.name != null && v.name!.toLowerCase().contains(_searchText)) ||
            v.doName.toLowerCase().contains(_searchText);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Top Compact Toolbar
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
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                  ),
                  child: Tooltip(
                    message: '${widget.manager.selectedConnection?.displayName ?? ""} (${widget.manager.selectedConnection?.ip ?? ""}:${widget.manager.selectedConnection?.port ?? ""})',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.manager.connections.any((c) => c.id == widget.manager.selectedConnectionId)
                            ? widget.manager.selectedConnectionId
                            : (widget.manager.connections.isNotEmpty ? widget.manager.connections.first.id : null),
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down, size: 18),
                        items: widget.manager.connections.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: c.isConnected ? Colors.greenAccent : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 160),
                                  child: Text(
                                    '${c.displayName} (${c.port})',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() {
                              widget.manager.selectedConnectionId = id;
                            });
                            widget.onDataChanged();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Search Box
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

                // Only Monitored Chip
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

                // Only Polling Chip
                Tooltip(
                  message: i18n.t('onlyPolling'),
                  child: SizedBox(
                    height: 32,
                    child: FilterChip(
                      label: Text(i18n.t('onlyPolling'), style: const TextStyle(fontSize: 12)),
                      selected: _onlyPolling,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      onSelected: (val) => setState(() => _onlyPolling = val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // FC Filter Dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[350]!),
                  ),
                  child: Tooltip(
                    message: 'FC: $_fcFilter',
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _fcFilter,
                        isDense: true,
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
                ),
                const SizedBox(width: 12),

                // Batch Actions
                Tooltip(
                  message: i18n.t('pollAll'),
                  child: SizedBox(
                    height: 32,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: _isPollingAll
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh, size: 15),
                      label: Text(i18n.t('pollAll'), style: const TextStyle(fontSize: 12)),
                      onPressed: (engine?.isConnected ?? false) && !_isPollingAll ? _pollAllNow : null,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('startPolling'),
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.play_circle_outline, size: 15, color: Colors.green),
                      label: Text(i18n.t('startPolling'), style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        for (final v in filtered) {
                          v.isPolling = true;
                        }
                        widget.onDataChanged();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: i18n.t('stopPolling'),
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 15, color: Colors.red),
                      label: Text(i18n.t('stopPolling'), style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        for (final v in allVars) {
                          v.isPolling = false;
                        }
                        widget.onDataChanged();
                        setState(() {});
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Data Table with Fixed Column Widths and Ellipsis + Tooltip
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(i18n.t('noMatchingPoints'), style: const TextStyle(color: Colors.grey)))
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
                        DataColumn(
                          label: SizedBox(
                            width: 50,
                            child: Tooltip(
                              message: i18n.t('colPin'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colPin'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 230,
                            child: Tooltip(
                              message: i18n.t('colRef'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colRef'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        const DataColumn(
                          label: SizedBox(
                            width: 55,
                            child: Tooltip(
                              message: 'Functional Constraint (FC)',
                              waitDuration: Duration(milliseconds: 200),
                              child: Text('FC', style: TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 80,
                            child: Tooltip(
                              message: i18n.t('colType'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colType'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 135,
                            child: Tooltip(
                              message: i18n.t('colLiveAcqVal'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colLiveAcqVal'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 105,
                            child: Tooltip(
                              message: i18n.t('colQuality'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colQuality'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 95,
                            child: Tooltip(
                              message: i18n.t('optTimestamp'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('optTimestamp'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 65,
                            child: Tooltip(
                              message: i18n.t('colPoll'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colPoll'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(
                            width: 120,
                            child: Tooltip(
                              message: i18n.t('colAction'),
                              waitDuration: const Duration(milliseconds: 200),
                              child: Text(i18n.t('colAction'), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ],
                      rows: filtered.map((v) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 50,
                                child: Tooltip(
                                  message: v.isMonitored ? i18n.t('onlyMonitored') : i18n.t('colPin'),
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: IconButton(
                                    icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border, size: 18),
                                    color: v.isMonitored ? Colors.amber : null,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                                    onPressed: () {
                                      setState(() => v.isMonitored = !v.isMonitored);
                                      widget.onDataChanged();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 230,
                                child: Tooltip(
                                  message: '${v.displayName}\n${v.reference}${v.displayDesc != null && v.displayDesc!.isNotEmpty ? '\n${v.displayDesc}' : ''}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: v.displayName != v.shortRef
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              v.displayName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            Text(
                                              v.shortRef,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ],
                                        )
                                      : Text(
                                          v.shortRef,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 55,
                                child: Tooltip(
                                  message: 'FC: ${v.fcCode}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: _fcBadge(v.fcCode),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 80,
                                child: Tooltip(
                                  message: '${i18n.t("colType")}: ${v.type.name}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: Text(
                                    v.type.name,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 135,
                                child: Tooltip(
                                  message: '${i18n.t("colLiveAcqVal")}: ${v.displayValue}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: v.type == IecBasicType.boolean
                                      ? Align(
                                          alignment: Alignment.centerLeft,
                                          child: Switch(
                                            value: v.value == true,
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (val) async {
                                              await engine?.writeVariable(v, val);
                                              setState(() {});
                                              widget.onDataChanged();
                                            },
                                          ),
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
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 105,
                                child: Tooltip(
                                  message: '${i18n.t("colQuality")}: ${v.qualityString} (0x${v.quality.toRadixString(16).padLeft(4, "0")})',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: v.quality == 0 ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      v.qualityString,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: v.quality == 0 ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 95,
                                child: Tooltip(
                                  message: '${i18n.t("optTimestamp")}: ${v.timestamp.toIso8601String()}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: Text(
                                    v.timestamp.toIso8601String().substring(11, 23),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 65,
                                child: Tooltip(
                                  message: '${i18n.t("colPoll")}: ${v.isPolling ? i18n.t("startPolling") : i18n.t("stopPolling")}',
                                  waitDuration: const Duration(milliseconds: 200),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Switch(
                                      value: v.isPolling,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (val) {
                                        setState(() => v.isPolling = val);
                                        widget.onDataChanged();
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 120,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildActionIconButton(
                                      icon: Icons.refresh,
                                      color: isDark ? Colors.lightBlue[300] : Colors.blue[700],
                                      tooltip: i18n.t('readSingle'),
                                      onPressed: () async {
                                        await engine?.readVariable(v);
                                        setState(() {});
                                        widget.onDataChanged();
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildActionIconButton(
                                      icon: Icons.edit_outlined,
                                      color: isDark ? Colors.tealAccent[400] : Colors.teal[700],
                                      tooltip: i18n.t('writeValueTooltip'),
                                      onPressed: () => _openWriteDialog(v),
                                    ),
                                    if (v.isControllable) ...[
                                      const SizedBox(width: 8),
                                      _buildActionIconButton(
                                        icon: Icons.power_settings_new,
                                        color: Colors.deepOrange,
                                        tooltip: i18n.t('remoteControl'),
                                        onPressed: () => _openControlDialog(v),
                                      ),
                                    ],
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

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: color?.withValues(alpha: isDark ? 0.15 : 0.08) ??
                  (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
              border: Border.all(
                color: color?.withValues(alpha: isDark ? 0.3 : 0.2) ??
                    (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                width: 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color ?? (isDark ? Colors.grey[300] : Colors.grey[700])),
          ),
        ),
      ),
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
