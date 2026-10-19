import 'dart:io';
import 'package:flutter/material.dart';
import '../../i18n/app_i18n.dart';
import '../../models/dictionary_service.dart';
import '../../models/scl_parser.dart';
import '../../protocol/iec61850_client_manager.dart';

class SclToolsTab extends StatefulWidget {
  final Iec61850ClientManager manager;
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

  void _applySclToActiveConnection() {
    final engine = widget.manager.activeEngine;
    if (engine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppI18n.instance.t('selectConnFirstModel'))),
      );
      return;
    }

    try {
      final res = SclParser.parseString(_xmlCtrl.text);
      engine.bindSclModel(res);
      engine.config.sclFilePath = _currentLoadedFile;
      widget.onDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppI18n.instance.t("sclAppliedSuccess")} IED: ${res.iedName}, ${AppI18n.instance.t("allVarsCount")}: ${res.variables.length}',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppI18n.instance.t("sclParseFailed")}: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  void _searchDictionary() {
    final q = _dictSearchCtrl.text.trim();
    if (q.isEmpty) return;

    final dict = DictionaryService.instance;
    final sb = StringBuffer();

    // 1. LN
    final lnDesc = dict.lookupLn(q);
    if (lnDesc != null) {
      sb.writeln('[${AppI18n.instance.t("dictLn")}] $q: $lnDesc');
    }

    // 2. DO
    final doDesc = dict.lookupDo(q);
    if (doDesc != null) {
      sb.writeln('[${AppI18n.instance.t("dictDo")}] $q: $doDesc');
    }

    // 3. DA
    final daDesc = dict.lookupDa(q);
    if (daDesc != null) {
      sb.writeln('[${AppI18n.instance.t("dictDa")}] $q: $daDesc');
    }

    // 4. CDC
    final cdcDesc = dict.lookupCdc(q);
    if (cdcDesc != null) {
      sb.writeln('[${AppI18n.instance.t("dictCdc")}] $q: $cdcDesc');
    }

    if (sb.isEmpty) {
      sb.writeln('${AppI18n.instance.t("dictNoDesc")}: "$q"');
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
        // Left Column: Template Selector & Dictionary Query
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Template Library Header
                Row(
                  children: [
                    const Icon(Icons.library_books, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text(i18n.t('builtinSclLibrary'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  i18n.t('selectTemplateDesc'),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(height: 10),

                // Template List
                ...List.generate(_templates.length, (i) {
                  final t = _templates[i];
                  final isSelected = _currentLoadedFile == t.filename;

                  return Card(
                    elevation: isSelected ? 2 : 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.grey[850]! : Colors.grey[300]!),
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      selected: isSelected,
                      title: Text(i18n.t(t.titleKey), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(i18n.t(t.descKey), style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () => _loadTemplate(t.filename),
                    ),
                  );
                }),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Custom Local SCL File Load
                Row(
                  children: [
                    const Icon(Icons.file_open, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(i18n.t('loadLocalScl'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customPathCtrl,
                  decoration: InputDecoration(
                    hintText: i18n.t('loadExternalSclHint'),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: Text(i18n.t('loadExternalContent')),
                  onPressed: () {
                    final path = _customPathCtrl.text.trim();
                    if (path.isNotEmpty) {
                      _loadTemplate(path);
                    }
                  },
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Standard IEC 61850 Dictionary Lookup
                Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(i18n.t('sclDictLookup'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dictSearchCtrl,
                        decoration: InputDecoration(
                          hintText: i18n.t('sclDictHint'),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _searchDictionary(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchDictionary,
                    ),
                  ],
                ),
                if (_dictSearchResult.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _dictSearchResult,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Right Column: XML Code Editor / Viewer & Apply Button
        Expanded(
          flex: 6,
          child: Column(
            children: [
              // Top Action Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252526) : const Color(0xFFF3F3F3),
                  border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${i18n.t("sclPreviewTitle")}: ${_currentLoadedFile.isEmpty ? i18n.t("unselected") : _currentLoadedFile}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(i18n.t('applySclToConn')),
                      onPressed: _applySclToActiveConnection,
                    ),
                  ],
                ),
              ),

              // XML Text Editor
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _xmlCtrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.35,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
