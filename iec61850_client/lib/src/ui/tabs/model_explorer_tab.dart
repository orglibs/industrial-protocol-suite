import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/client_variable_model.dart';
import '../../models/dictionary_service.dart';
import '../../protocol/iec61850_client_manager.dart';
import '../dialogs/control_operation_dialog.dart';
import '../dialogs/write_variable_dialog.dart';

class ModelExplorerTab extends StatefulWidget {
  final Iec61850ClientManager manager;
  final VoidCallback onDataChanged;

  const ModelExplorerTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<ModelExplorerTab> createState() => _ModelExplorerTabState();
}

class _ModelExplorerTabState extends State<ModelExplorerTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  ClientVariableModel? _selectedVariable;
  String _filterText = '';
  bool _isDiscovering = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _filterText = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _discoverOnline() async {
    final engine = widget.manager.activeEngine;
    if (engine == null || !engine.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('connectFirstDiscover'))),
      );
      return;
    }

    setState(() => _isDiscovering = true);
    try {
      final ok = await engine.discoverOnlineModel();
      if (ok && mounted) {
        widget.onDataChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppI18n.instance.tf('onlineDiscoverSuccess', {'count': '${engine.allVariables.length}'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final allVars = engine?.allVariables ?? [];

    final filteredVars = _filterText.isEmpty
        ? allVars
        : allVars.where((v) =>
            v.reference.toLowerCase().contains(_filterText) ||
            v.shortRef.toLowerCase().contains(_filterText) ||
            v.displayName.toLowerCase().contains(_filterText) ||
            (v.name != null && v.name!.toLowerCase().contains(_filterText)) ||
            v.lnName.toLowerCase().contains(_filterText) ||
            v.doName.toLowerCase().contains(_filterText)).toList();

    return Row(
      children: [
        // Left Column: SCL Tree & Variable List
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Top Search Bar & Online Discover Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: Tooltip(
                            message: i18n.t('searchLnDo'),
                            child: TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: i18n.t('searchLnDo'),
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                suffixIcon: _filterText.isNotEmpty
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
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: i18n.t('onlineDiscover'),
                        child: SizedBox(
                          height: 32,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _isDiscovering
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.travel_explore, size: 16),
                            label: Text(i18n.t('onlineDiscover'), style: const TextStyle(fontSize: 12)),
                            onPressed: _isDiscovering ? null : _discoverOnline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Header Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.device_hub, size: 16, color: Theme.of(context).colorScheme.primary),
                      Expanded(
                        child: Text(
                          'IED: ${engine?.scl?.iedName ?? i18n.t("connectedIed")} | ${i18n.t("allVarsCount")}: ${allVars.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${i18n.t("matchedVars")}: ${filteredVars.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Column Header Bar for Variables List
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252526) : const Color(0xFFF0F2F5),
                    border: Border(
                      top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          'FC',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Tooltip(
                          message: i18n.t('colRef'),
                          waitDuration: const Duration(milliseconds: 200),
                          child: Text(
                            i18n.t('colRef'),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: Tooltip(
                          message: i18n.t('colLiveAcqVal'),
                          waitDuration: const Duration(milliseconds: 200),
                          child: Text(
                            i18n.t('colLiveAcqVal'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: Text(
                          i18n.t('colAction'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Variables List
                Expanded(
                  child: filteredVars.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.device_unknown, size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(i18n.t('noDataPoints'), style: const TextStyle(color: Colors.grey)),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                icon: const Icon(Icons.travel_explore),
                                label: Text(i18n.t('mmsOnlineDiscover')),
                                onPressed: _discoverOnline,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredVars.length,
                          itemBuilder: (context, index) {
                            final v = filteredVars[index];
                            final isSelected = _selectedVariable?.reference == v.reference;

                            return InkWell(
                              onTap: () {
                                setState(() => _selectedVariable = v);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : null,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // FC Badge (width: 36)
                                    SizedBox(
                                      width: 36,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _fcBadge(v.fcCode),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 运行行为 / 变量标识 (Expanded with Tooltip & Ellipsis)
                                    Expanded(
                                      child: Tooltip(
                                        message: '${v.displayName}\n${v.shortRef}\n${v.reference}${v.displayDesc != null && v.displayDesc!.isNotEmpty ? '\n${v.displayDesc}' : ''}',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    v.displayName != v.shortRef
                                                        ? '${v.displayName} (${v.shortRef})'
                                                        : v.shortRef,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                if (v.isControllable) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.deepOrange.withOpacity(0.18),
                                                      borderRadius: BorderRadius.circular(3),
                                                    ),
                                                    child: Text(
                                                      i18n.t('controllable'),
                                                      style: const TextStyle(fontSize: 9, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '${v.type.name}  |  ${v.reference}',
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
                                    const SizedBox(width: 8),

                                    // 采集值 (Fixed Width: 100 with Monospace, Ellipsis & Tooltip)
                                    SizedBox(
                                      width: 100,
                                      child: Tooltip(
                                        message: '${i18n.t("colLiveAcqVal")}: ${v.displayValue}',
                                        waitDuration: const Duration(milliseconds: 200),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            v.displayValue,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.lightBlue[300] : Colors.blue[900],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 操作按钮组 (Fixed Width: 110, with 8px spacing)
                                    SizedBox(
                                      width: 110,
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
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Inspector Details Panel
        Expanded(
          flex: 6,
          child: _selectedVariable == null
              ? Center(child: Text(i18n.t('selectAttrHint'), style: const TextStyle(color: Colors.grey)))
              : _buildInspectorPanel(_selectedVariable!),
        ),
      ],
    );
  }

  Widget _buildInspectorPanel(ClientVariableModel v) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final engine = widget.manager.activeEngine;
    final dict = DictionaryService.instance;
    final lnDesc = dict.getLogicalNode(v.lnName);
    final doDesc = dict.getDataObject(v.doName);
    final daDesc = dict.getDataAttribute(v.daName);
    final cdcDesc = (v.cdc != null && v.cdc!.isNotEmpty) ? dict.getCdc(v.cdc!) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _fcBadge(v.fcCode),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v.displayName != v.shortRef)
                      Tooltip(
                        message: v.displayName,
                        waitDuration: const Duration(milliseconds: 200),
                        child: Text(
                          v.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    Tooltip(
                      message: v.shortRef,
                      waitDuration: const Duration(milliseconds: 200),
                      child: Text(
                        v.shortRef,
                        style: TextStyle(
                          fontSize: v.displayName != v.shortRef ? 12 : 16,
                          fontWeight: v.displayName != v.shortRef ? FontWeight.normal : FontWeight.bold,
                          color: v.displayName != v.shortRef ? (isDark ? Colors.grey[400] : Colors.grey[700]) : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(v.isMonitored ? Icons.bookmark : Icons.bookmark_border),
                color: v.isMonitored ? Colors.amber : null,
                tooltip: i18n.t('tabMonitor'),
                onPressed: () {
                  setState(() => v.isMonitored = !v.isMonitored);
                  widget.onDataChanged();
                },
              ),
            ],
          ),
          Tooltip(
            message: 'MMS Reference: ${v.reference}',
            waitDuration: const Duration(milliseconds: 200),
            child: Text(
              'MMS Reference: ${v.reference}',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Live Value & Operations Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('liveControlTitle'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(i18n.t('acqValLabel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 140,
                        child: Tooltip(
                          message: '${i18n.t("acqValLabel")}${v.displayValue}',
                          waitDuration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              v.displayValue,
                              style: TextStyle(
                                fontSize: 18,
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
                      const Spacer(),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(i18n.t('readSingle')),
                        onPressed: () async {
                          await engine?.readVariable(v);
                          setState(() {});
                          widget.onDataChanged();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(i18n.t('writeVal')),
                        onPressed: () => _openWriteDialog(v),
                      ),
                      if (v.isControllable) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange[700]),
                          icon: const Icon(Icons.power_settings_new, size: 16),
                          label: Text(i18n.t('controlCmd')),
                          onPressed: () => _openControlDialog(v),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('quality'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.qualityString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('updateTime'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.timestamp.toIso8601String().substring(11, 23),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('baseDataType'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.type.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Standard Metadata Dictionary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.library_books, size: 18),
                      const SizedBox(width: 8),
                      Text(i18n.t('standardDictMeta'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dictRow(i18n.t('dictLn'), v.lnName, lnDesc?.display),
                  _dictRow(i18n.t('dictDo'), v.doName, doDesc?.display),
                  _dictRow(i18n.t('dictDa'), v.daName, daDesc?.display),
                  if (v.cdc != null && v.cdc!.isNotEmpty)
                    _dictRow(i18n.t('dictCdc'), v.cdc!, cdcDesc?.display),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictRow(String title, String code, String? explanation) {
    final i18n = AppI18n.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Tooltip(
              message: title,
              waitDuration: const Duration(milliseconds: 200),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          Tooltip(
            message: code,
            waitDuration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Tooltip(
              message: explanation ?? i18n.t('dictNoDesc'),
              waitDuration: const Duration(milliseconds: 200),
              child: Text(
                explanation ?? i18n.t('dictNoDesc'),
                style: TextStyle(fontSize: 12, color: explanation != null ? null : Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
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
