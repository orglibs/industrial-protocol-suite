import 'dart:convert';
import 'dart:io';
import '../i18n/app_i18n.dart';

class IecDesc {
  final String name;
  final String? descZh;
  final String? descEn;
  final String? cdc;

  IecDesc({required this.name, this.descZh, this.descEn, this.cdc});

  String get display => localized();

  String localized([AppLanguage? lang]) {
    final target = lang ?? AppI18n.instance.currentLanguage;
    if (target == AppLanguage.zhCN) {
      return descZh ?? descEn ?? name;
    } else {
      return descEn ?? descZh ?? name;
    }
  }
}

class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  final Map<String, IecDesc> _cdcMap = {};
  final Map<String, IecDesc> _lnMap = {};
  final Map<String, IecDesc> _doMap = {};
  final Map<String, IecDesc> _daMap = {};
  bool _isLoaded = false;

  static final Map<String, ({String zh, String en})> _standardDaDescs = {
    'STVAL': (zh: '状态值', en: 'Status Value'),
    'Q': (zh: '品质', en: 'Quality'),
    'T': (zh: '时标', en: 'Timestamp'),
    'MAG': (zh: '幅值', en: 'Magnitude'),
    'F': (zh: '浮点值', en: 'Floating Point Value'),
    'I': (zh: '整数值', en: 'Integer Value'),
    'CTLMODEL': (zh: '控制模式', en: 'Control Model'),
    'GENERAL': (zh: '总体状态', en: 'General Status'),
    'ORIGIN': (zh: '操作始发者', en: 'Originator'),
    'OPER': (zh: '控制操作', en: 'Operate'),
    'CANCEL': (zh: '取消操作', en: 'Cancel'),
    'SBO': (zh: '操作前选择', en: 'Select Before Operate'),
    'SBOW': (zh: '带值操作前选择', en: 'Select Before Operate with Value'),
    'PHSA': (zh: 'A相', en: 'Phase A'),
    'PHSB': (zh: 'B相', en: 'Phase B'),
    'PHSC': (zh: 'C相', en: 'Phase C'),
    'NEUT': (zh: '中性点', en: 'Neutral'),
    'CVAL': (zh: '复数值', en: 'Complex Value'),
    'UNITS': (zh: '单位', en: 'Units'),
    'SMPRATE': (zh: '采样率', en: 'Sample Rate'),
    'SUBENA': (zh: '取代使能', en: 'Substitution Enable'),
    'SUBVAL': (zh: '取代值', en: 'Substitution Value'),
    'SUBQ': (zh: '取代品质', en: 'Substitution Quality'),
    'SUBID': (zh: '取代标识', en: 'Substitution ID'),
    'D': (zh: '描述', en: 'Description'),
    'DU': (zh: 'Unicode描述', en: 'Unicode Description'),
    'CDCNAME': (zh: 'CDC名称', en: 'CDC Name'),
    'CDCNS': (zh: 'CDC命名空间', en: 'CDC Namespace'),
    'DATANS': (zh: '数据命名空间', en: 'Data Namespace'),
    'MIN': (zh: '最小值', en: 'Minimum'),
    'MAX': (zh: '最大值', en: 'Maximum'),
    'STEPSIZE': (zh: '步长', en: 'Step Size'),
    'RANGE': (zh: '范围', en: 'Range'),
  };

  Future<void> load() async {
    if (_isLoaded) return;

    // Search in multiple possible paths
    final candidateDirs = [
      'assets/json',
      'iec61850_server/assets/json',
      '../iec61850_server/assets/json',
      '/home/douqi/workspaces/nixiangwork/iec104serversimulator/iec61850_server/assets/json',
      '/home/douqi/Downloads/IEC61850ServerSimulator-2.2.0.2-linux-x64/Json',
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
                cdc: item['cdc'] as String?,
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  IecDesc? getCdc(String cdcName) => _cdcMap[cdcName.toUpperCase()];

  IecDesc? getLogicalNode(String lnClassOrName) {
    final upper = lnClassOrName.toUpperCase().trim();
    if (_lnMap.containsKey(upper)) return _lnMap[upper];
    // Strip trailing digits (e.g. GGIO1 -> GGIO), but preserve LLN0
    if (upper != 'LLN0') {
      final stripped = upper.replaceAll(RegExp(r'\d+$'), '');
      if (_lnMap.containsKey(stripped)) return _lnMap[stripped];
    }
    return null;
  }

  IecDesc? getDataObject(String doName) {
    final upper = doName.toUpperCase().trim();
    if (_doMap.containsKey(upper)) return _doMap[upper];
    // Strip trailing digits (e.g. AnIn2 -> AnIn1 or AnIn)
    final stripped = upper.replaceAll(RegExp(r'\d+$'), '');
    if (_doMap.containsKey(stripped)) return _doMap[stripped];
    if (upper.contains('.')) {
      final parts = upper.split('.');
      for (final part in parts) {
        if (_doMap.containsKey(part)) return _doMap[part];
      }
    }
    return null;
  }

  IecDesc? getDataAttribute(String daName) {
    final upper = daName.toUpperCase().trim();
    final direct = _daMap[upper];
    if (direct != null && (direct.descZh != null || direct.descEn != null)) {
      return direct;
    }
    // Check leaf part if dotted (e.g. mag.f -> f)
    final leaf = upper.contains('.') ? upper.split('.').last : upper;
    if (_standardDaDescs.containsKey(leaf)) {
      final std = _standardDaDescs[leaf]!;
      return IecDesc(name: daName, descZh: std.zh, descEn: std.en);
    }
    if (_standardDaDescs.containsKey(upper)) {
      final std = _standardDaDescs[upper]!;
      return IecDesc(name: daName, descZh: std.zh, descEn: std.en);
    }
    return direct;
  }
}
