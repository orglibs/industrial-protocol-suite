import '../../i18n/app_i18n.dart';
import 'package:flutter/material.dart';
import '../../models/dictionary_service.dart';
import '../../models/scl_models.dart';
import '../../models/server_variable_model.dart';
import '../../protocol/iec61850_server_manager.dart';
import '../dialogs/simulation_dialog.dart';
import '../dialogs/write_value_dialog.dart';

class ModelExplorerTab extends StatefulWidget {
  final Iec61850ServerManager manager;
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
  ServerVariableModel? _selectedVariable;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    DictionaryService.instance.load().then((_) {
      if (mounted) setState(() {});
    });
    _searchCtrl.addListener(() {
      setState(() {
        _filterText = _searchCtrl.text.trim().toLowerCase();
      });
    });
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
    final dict = DictionaryService.instance;
    final scl = widget.manager.engine.scl;
    final allVars = widget.manager.engine.allVariables;

    final filteredVars = _filterText.isEmpty
        ? allVars
        : allVars.where((v) {
            final t = _filterText;
            final lnDesc = dict.getLogicalNode(v.lnName)?.display.toLowerCase() ?? '';
            final doDesc = dict.getDataObject(v.doName)?.display.toLowerCase() ?? '';
            return v.reference.toLowerCase().contains(t) ||
                v.shortRef.toLowerCase().contains(t) ||
                v.displayName.toLowerCase().contains(t) ||
                v.lnName.toLowerCase().contains(t) ||
                v.doName.toLowerCase().contains(t) ||
                v.daName.toLowerCase().contains(t) ||
                (v.cdc != null && v.cdc!.toLowerCase().contains(t)) ||
                lnDesc.contains(t) ||
                doDesc.contains(t);
          }).toList();

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
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: i18n.t('searchLnDo'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _filterText.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                // Header Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: isDark ? Colors.grey[900] : Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(Icons.device_hub, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'IED: ${scl?.ied.displayName ?? scl?.iedName ?? i18n.t("unloaded")} | ${i18n.t("allVarsCount")}: ${allVars.length}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${i18n.t("matchedVars")}: ${filteredVars.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Variables List View
                Expanded(
                  child: filteredVars.isEmpty
                      ? Center(
                          child: Text(
                            scl == null ? i18n.t('noSclLoaded') : i18n.t('noMatchingVars'),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredVars.length,
                          itemBuilder: (context, index) {
                            final v = filteredVars[index];
                            final isSelected = _selectedVariable?.reference == v.reference;
                            final lnDesc = dict.getLogicalNode(v.lnName);
                            final lnText = lnDesc != null ? '  |  ${lnDesc.display}' : '';

                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              title: Row(
                                children: [
                                  _fcBadge(v.fcCode),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      v.displayName != v.shortRef
                                          ? '${v.displayName} (${v.shortRef})'
                                          : '${v.ldInst}/${v.lnName}.${v.doName}.${v.daName}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${v.type.name}$lnText  |  ${i18n.t("valLabel")} ${v.displayValue}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  if (v.simulation.enabled) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(i18n.t('waveBadge'), style: const TextStyle(fontSize: 10, color: Colors.blue)),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.edit, size: 16),
                                tooltip: i18n.t('writeValueTooltip'),
                                onPressed: () => _openWriteDialog(v),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedVariable = v;
                                });
                              },
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
              ? Center(
                  child: Text(i18n.t('selectAttrHint'), style: const TextStyle(color: Colors.grey)),
                )
              : _buildInspectorPanel(_selectedVariable!),
        ),
      ],
    );
  }

  Widget _buildInspectorPanel(ServerVariableModel v) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dict = DictionaryService.instance;
    final scl = widget.manager.engine.scl;
    final lnDesc = dict.getLogicalNode(v.lnName);
    final doDesc = dict.getDataObject(v.doName);
    final daDesc = dict.getDataAttribute(v.daName);
    final cdcCode = v.cdc ?? doDesc?.cdc;
    final cdcDesc = cdcCode != null ? dict.getCdc(cdcCode) : null;

    final ld = scl?.ied.findLDevice(v.ldInst);
    final ln = ld?.findLN(v.lnName);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Localized Name, Short Reference, MMS Reference
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fcBadge(v.fcCode),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 2),
                    Tooltip(
                      message: v.shortRef,
                      waitDuration: const Duration(milliseconds: 200),
                      child: Text(
                        v.shortRef,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tooltip(
                      message: 'MMS Reference: ${v.reference}',
                      waitDuration: const Duration(milliseconds: 200),
                      child: Text(
                        'MMS Reference: ${v.reference}',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500]),
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
                tooltip: v.isMonitored ? i18n.t('pinnedTooltip') : i18n.t('unpinnedTooltip'),
                onPressed: () {
                  setState(() {
                    v.isMonitored = !v.isMonitored;
                  });
                  widget.onDataChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Live Value & Quick Edit Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(i18n.t('liveDataCard'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(i18n.t('currentValLabel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 150,
                            child: Tooltip(
                              message: v.displayValue,
                              waitDuration: const Duration(milliseconds: 200),
                              child: InkWell(
                                onTap: () => _openWriteDialog(v),
                                borderRadius: BorderRadius.circular(4),
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
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text(i18n.t('writeVal')),
                            onPressed: () => _openWriteDialog(v),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.waves, size: 16),
                            label: Text(i18n.t('simWave')),
                            onPressed: () => _openSimDialog(v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('qualityTitle'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.qualityString, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i18n.t('updateTimeTitle'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FC', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(v.fc.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
                      Text(i18n.t('standardDictTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (cdcCode != null)
                    _dictRow(i18n.t('dictCdc'), cdcCode, cdcDesc?.display),
                  _dictRow(i18n.t('dictLn'), v.lnName, lnDesc?.display),
                  _dictRow(i18n.t('dictDo'), v.doName, doDesc?.display),
                  _dictRow(i18n.t('dictDa'), v.daName, daDesc?.display),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // SCL Hierarchy Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_tree_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(i18n.t('sclHierarchyTitle'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _dictRow(i18n.t('sclHierarchyIed'), scl?.iedName ?? '-', scl?.ied.displayName),
                  _dictRow(i18n.t('sclHierarchyLd'), v.ldInst, ld?.displayName),
                  _dictRow(i18n.t('sclHierarchyLn'), v.lnName, ln?.displayName ?? lnDesc?.display),
                  _dictRow(i18n.t('sclHierarchyDo'), v.doName, doDesc?.display),
                  if (cdcCode != null)
                    _dictRow(i18n.t('sclHierarchyCdc'), cdcCode, cdcDesc?.display),
                  _dictRow(i18n.t('sclHierarchyDa'), v.daName, daDesc?.display),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dictRow(String title, String code, String? explanation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              explanation ?? AppI18n.instance.t('noBuiltinDesc'),
              style: TextStyle(fontSize: 12, color: explanation != null ? null : Colors.grey),
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

    return Tooltip(
      message: FunctionalConstraint.fromCode(fc).label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          fc,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
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
