import 'dart:convert';
import 'dart:io';
import '../i18n/app_i18n.dart';

class IecDesc {
  final String name;
  final String? descZh;
  final String? descEn;

  IecDesc({required this.name, this.descZh, this.descEn});

  String displayFor(AppLanguage lang) {
    if (lang == AppLanguage.zhCN) {
      return (descZh != null && descZh!.isNotEmpty) ? descZh! : (descEn ?? name);
    } else {
      return (descEn != null && descEn!.isNotEmpty) ? descEn! : (descZh ?? name);
    }
  }

  String get display => displayFor(AppI18n.instance.currentLanguage);
}

class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  final Map<String, IecDesc> _cdcMap = {};
  final Map<String, IecDesc> _lnMap = {};
  final Map<String, IecDesc> _doMap = {};
  final Map<String, IecDesc> _daMap = {};
  bool _isLoaded = false;

  void _ensureLoaded() {
    if (!_isLoaded) {
      loadSync();
    }
  }

  void loadSync() {
    if (_isLoaded) return;

    final candidateDirs = [
      'assets/json',
      '../iec61850_client/assets/json',
      '/home/douqi/workspaces/nixiangwork/iec104serversimulator/iec61850_client/assets/json',
      '/home/douqi/Downloads/IEC61850ClientSimulator-2.2.0.2-linux-x64/Json',
    ];

    Directory? foundDir;
    for (final p in candidateDirs) {
      final dir = Directory(p);
      if (dir.existsSync()) {
        foundDir = dir;
        break;
      }
    }

    if (foundDir != null) {
      _loadJson(foundDir, 'cdc.json', _cdcMap);
      _loadJson(foundDir, 'logicalnode.json', _lnMap);
      _loadJson(foundDir, 'dataobject.json', _doMap);
      _loadJson(foundDir, 'dataattribute.json', _daMap);
      _loadJson(foundDir, 'alldataattribute.json', _daMap);
    }

    _isLoaded = true;
  }

  Future<void> load() async {
    loadSync();
  }

  void _loadJson(Directory dir, String filename, Map<String, IecDesc> map) {
    try {
      final file = File('${dir.path}/$filename');
      if (file.existsSync()) {
        var content = file.readAsStringSync();
        if (content.startsWith('\uFEFF')) {
          content = content.substring(1);
        }
        final list = jsonDecode(content);
        if (list is List) {
          for (final item in list) {
            final name = item['name'] as String?;
            if (name != null && name.isNotEmpty) {
              final upper = name.toUpperCase();
              final descZh = item['desc_zh'] as String?;
              final descEn = item['desc_en'] as String?;
              final existing = map[upper];
              map[upper] = IecDesc(
                name: name,
                descZh: (descZh != null && descZh.isNotEmpty) ? descZh : existing?.descZh,
                descEn: (descEn != null && descEn.isNotEmpty) ? descEn : existing?.descEn,
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  IecDesc? getCdc(String cdcName) {
    _ensureLoaded();
    return _cdcMap[cdcName.toUpperCase()];
  }

  IecDesc? getLogicalNode(String lnClass) {
    _ensureLoaded();
    final upper = lnClass.toUpperCase();
    if (_lnMap.containsKey(upper)) return _lnMap[upper];
    final noDigits = upper.replaceAll(RegExp(r'\d+'), '');
    if (_lnMap.containsKey(noDigits)) return _lnMap[noDigits];
    return null;
  }

  IecDesc? getDataObject(String doName) {
    _ensureLoaded();
    final upper = doName.toUpperCase();
    if (_doMap.containsKey(upper)) return _doMap[upper];
    final norm1 = upper.replaceAll(RegExp(r'\d+'), '1');
    if (_doMap.containsKey(norm1)) return _doMap[norm1];
    final noDigits = upper.replaceAll(RegExp(r'\d+'), '');
    if (_doMap.containsKey(noDigits)) return _doMap[noDigits];
    return null;
  }

  IecDesc? getDataAttribute(String daName) {
    _ensureLoaded();
    final upper = daName.toUpperCase();
    if (_daMap.containsKey(upper)) return _daMap[upper];
    if (upper.contains('.')) {
      final parts = upper.split('.');
      if (_daMap.containsKey(parts.first)) return _daMap[parts.first];
      if (_daMap.containsKey(parts.last)) return _daMap[parts.last];
    }
    return null;
  }

  String? lookupLn(String lnClass) => getLogicalNode(lnClass)?.display;
  String? lookupDo(String doName) => getDataObject(doName)?.display;
  String? lookupDa(String daName) => getDataAttribute(daName)?.display;
  String? lookupCdc(String cdcName) => getCdc(cdcName)?.display;
}
