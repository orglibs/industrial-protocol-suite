import '../../i18n/app_i18n.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/dictionary_service.dart';
import '../../models/scl_parser.dart';
import '../../protocol/iec61850_server_manager.dart';

class SclToolsTab extends StatefulWidget {
  final Iec61850ServerManager manager;
  final VoidCallback onDataChanged;

  const SclToolsTab({
    super.key,
    required this.manager,
    required this.onDataChanged,
  });

  @override
  State<SclToolsTab> createState() => _SclToolsTabState();
}

class _SclToolsTabState extends State<SclToolsTab> {
  final TextEditingController _xmlCtrl = TextEditingController();
  final TextEditingController _customPathCtrl = TextEditingController();
  final TextEditingController _dictSearchCtrl = TextEditingController();

  String _currentLoadedFile = '';
  String _dictSearchResult = '';

  static const List<({String titleKey, String filename, String descKey})> _templates = [
    (
      titleKey: 'tplBasicIoTitle',
      filename: 'assets/examples/server_example_basic_io.icd',
      descKey: 'tplBasicIoDesc',
    ),
    (
      titleKey: 'tplControlTitle',
      filename: 'assets/examples/server_example_control.icd',
      descKey: 'tplControlDesc',
    ),
    (
      titleKey: 'tplGooseTitle',
      filename: 'assets/examples/server_example_goose.icd',
      descKey: 'tplGooseDesc',
    ),
    (
      titleKey: 'tpl61400Title',
      filename: 'assets/examples/server_example_61400_25.icd',
      descKey: 'tpl61400Desc',
    ),
    (
      titleKey: 'tplSgTitle',
      filename: 'assets/examples/server_example_sg.icd',
      descKey: 'tplSgDesc',
    ),
    (
      titleKey: 'tplCaTitle',
      filename: 'assets/examples/server_example_ca.icd',
      descKey: 'tplCaDesc',
    ),
    (
      titleKey: 'tplDeadbandTitle',
      filename: 'assets/examples/server_example_deadband.icd',
      descKey: 'tplDeadbandDesc',
    ),
    (
      titleKey: 'tplSimpleTitle',
      filename: 'assets/examples/server_example_simple.icd',
      descKey: 'tplSimpleDesc',
    ),
    (
      titleKey: 'tplSubstTitle',
      filename: 'assets/examples/server_example_substitution.icd',
      descKey: 'tplSubstDesc',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTemplate(_templates.first.filename);
  }

  @override
  void dispose() {
    _xmlCtrl.dispose();
    _customPathCtrl.dispose();
    _dictSearchCtrl.dispose();
    super.dispose();
  }

  void _loadTemplate(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) {
        final content = f.readAsStringSync();
        _xmlCtrl.text = content;
        _currentLoadedFile = path;
        setState(() {});
      }
    } catch (_) {}
  }

  void _applyModel() {
    try {
      final res = SclParser.parse(_xmlCtrl.text);
      widget.manager.loadScl(res);
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppI18n.instance.t("sclAppliedSuccess")} IED: ${res.iedName}, ${AppI18n.instance.t("allVarsCount")}: ${res.variables.length}'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppI18n.instance.t("sclParseFailed")}: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _searchDictionary(String query) {
    final q = query.trim().toUpperCase();
    if (q.isEmpty) {
      setState(() => _dictSearchResult = '');
      return;
    }

    final dict = DictionaryService.instance;
    final cdc = dict.getCdc(q);
    final ln = dict.getLogicalNode(q);
    final doItem = dict.getDataObject(q);
    final da = dict.getDataAttribute(q);

    final sb = StringBuffer();
    if (cdc != null) sb.writeln('[${AppI18n.instance.t("dictCdc")}] ${cdc.name}: ${cdc.display}');
    if (ln != null) sb.writeln('[${AppI18n.instance.t("dictLnType")}] ${ln.name}: ${ln.display}');
    if (doItem != null) sb.writeln('[${AppI18n.instance.t("dictDoType")}] ${doItem.name}: ${doItem.display}');
    if (da != null) sb.writeln('[${AppI18n.instance.t("dictDaType")}] ${da.name}: ${da.display}');

    if (sb.isEmpty) {
      sb.writeln('${AppI18n.instance.t("dictNotFound")} "$query"');
    }

    setState(() {
      _dictSearchResult = sb.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Left Column: Template Library & Dictionary Search
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(i18n.t('builtinSclLibrary'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ..._templates.map((tpl) {
                  final isLoaded = _currentLoadedFile == tpl.filename;
                  return Card(
                    elevation: isLoaded ? 3 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: isLoaded
                          ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                          : BorderSide.none,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, size: 16, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(i18n.t(tpl.titleKey), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(i18n.t(tpl.descKey), style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.preview, size: 14),
                                label: Text(i18n.t('viewCode'), style: const TextStyle(fontSize: 11)),
                                onPressed: () => _loadTemplate(tpl.filename),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.play_arrow, size: 14),
                                label: Text(i18n.t('applyModelOneClick'), style: const TextStyle(fontSize: 11)),
                                onPressed: () {
                                  _loadTemplate(tpl.filename);
                                  _applyModel();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(height: 24),
                // Dictionary Lookup
                Text(i18n.t('sclDictLookup'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _dictSearchCtrl,
                  decoration: InputDecoration(
                    hintText: i18n.t('sclDictHint'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      onPressed: () => _searchDictionary(_dictSearchCtrl.text),
                    ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onSubmitted: _searchDictionary,
                ),
                if (_dictSearchResult.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(_dictSearchResult, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right Column: SCL XML Code Editor & Apply
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'SCL (ICD/CID/SCD) [$_currentLoadedFile]',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(i18n.t('parseAndUpdateServerModel')),
                      onPressed: _applyModel,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _xmlCtrl,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
