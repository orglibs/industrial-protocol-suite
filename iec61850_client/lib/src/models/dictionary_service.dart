import 'dart:convert';
import 'dart:io';

class IecDesc {
  final String name;
  final String? descZh;
  final String? descEn;

  IecDesc({required this.name, this.descZh, this.descEn});

  String get display => descZh ?? descEn ?? name;
}

class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  final Map<String, IecDesc> _cdcMap = {};
  final Map<String, IecDesc> _lnMap = {};
  final Map<String, IecDesc> _doMap = {};
  final Map<String, IecDesc> _daMap = {};
  bool _isLoaded = false;

  Future<void> load() async {
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

  void _loadJson(Directory dir, String filename, Map<String, IecDesc> map) {
    try {
      final file = File('${dir.path}/$filename');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final list = jsonDecode(content);
        if (list is List) {
          for (final item in list) {
            final name = item['name'] as String?;
            if (name != null) {
              map[name.toUpperCase()] = IecDesc(
                name: name,
                descZh: item['desc_zh'] as String?,
                descEn: item['desc_en'] as String?,
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  IecDesc? getCdc(String cdcName) => _cdcMap[cdcName.toUpperCase()];
  IecDesc? getLogicalNode(String lnClass) => _lnMap[lnClass.toUpperCase()];
  IecDesc? getDataObject(String doName) => _doMap[doName.toUpperCase()];
  IecDesc? getDataAttribute(String daName) => _daMap[daName.toUpperCase()];

  String? lookupLn(String lnClass) => getLogicalNode(lnClass)?.display;
  String? lookupDo(String doName) => getDataObject(doName)?.display;
  String? lookupDa(String daName) => getDataAttribute(daName)?.display;
  String? lookupCdc(String cdcName) => getCdc(cdcName)?.display;
}
