import 'scl_models.dart';

class ClientVariableModel {
  final String reference;
  final String iedName;
  final String ldInst;
  final String lnName;
  final String doName;
  final String daName;
  final FunctionalConstraint fc;
  final IecBasicType type;

  dynamic _value;
  dynamic previousValue;
  dynamic get value => _value;
  set value(dynamic v) {
    previousValue = _value;
    _value = v;
    timestamp = DateTime.now();
  }

  int quality;
  DateTime timestamp;
  bool isMonitored;
  bool isPolling;
  int pollIntervalMs;
  String? desc;
  String? cdc;
  int? ctlModel;

  ClientVariableModel({
    required this.reference,
    required this.iedName,
    required this.ldInst,
    required this.lnName,
    required this.doName,
    required this.daName,
    required this.fc,
    required this.type,
    dynamic initialValue,
    this.quality = 0,
    DateTime? timestamp,
    this.isMonitored = false,
    this.isPolling = false,
    this.pollIntervalMs = 1000,
    this.desc,
    this.cdc,
    this.ctlModel,
  })  : _value = initialValue ?? _defaultValueForType(type),
        previousValue = initialValue,
        timestamp = timestamp ?? DateTime.now();

  static dynamic _defaultValueForType(IecBasicType type) {
    switch (type) {
      case IecBasicType.boolean:
        return false;
      case IecBasicType.int8:
      case IecBasicType.int16:
      case IecBasicType.int32:
      case IecBasicType.int64:
      case IecBasicType.uint8:
      case IecBasicType.uint16:
      case IecBasicType.uint32:
        return 0;
      case IecBasicType.float32:
      case IecBasicType.float64:
        return 0.0;
      case IecBasicType.bitString:
        return '00';
      case IecBasicType.octetString:
        return '00 00';
      case IecBasicType.utcTime:
        return DateTime.now().toIso8601String();
      case IecBasicType.quality:
        return 0;
      default:
        return '';
    }
  }

  String get shortRef => '$ldInst/$lnName.$doName.$daName[$fcCode]';
  String get mmsRef => '$ldInst/$lnName\$$fcCode\$$doName\$$daName';
  String get fcCode => fc.code;

  bool get isControllable =>
      fc == FunctionalConstraint.co ||
      ctlModel != null && ctlModel! > 0 ||
      doName.contains('SPCSO') ||
      doName.contains('Pos') ||
      daName == 'ctlVal' ||
      daName == 'Oper';

  String get displayValue {
    if (_value == null) return '-';
    if (type == IecBasicType.float32 || type == IecBasicType.float64) {
      if (_value is num) return (_value as num).toStringAsFixed(3);
    }
    return _value.toString();
  }

  String get qualityString {
    if (quality == 0) return '有效 (Good)';
    if ((quality & 0x01) != 0) return '无效 (Invalid)';
    if ((quality & 0x02) != 0) return '溢出 (Overflow)';
    if ((quality & 0x04) != 0) return '超范围 (OutOfRange)';
    if ((quality & 0x08) != 0) return '坏参考 (BadRef)';
    if ((quality & 0x10) != 0) return '抖动 (Oscillatory)';
    if ((quality & 0x20) != 0) return '故障 (Failure)';
    if ((quality & 0x40) != 0) return '陈旧 (OldData)';
    if ((quality & 0x2000) != 0) return '测试 (Test)';
    if ((quality & 0x4000) != 0) return '人工闭锁 (Blocked)';
    return '疑问 (0x${quality.toRadixString(16)})';
  }

  Map<String, dynamic> toJson() => {
    'Reference': reference,
    'IedName': iedName,
    'LdInst': ldInst,
    'LnName': lnName,
    'DoName': doName,
    'DaName': daName,
    'FC': fc.code,
    'Type': type.name,
    'Value': _value,
    'Quality': quality,
    'IsMonitored': isMonitored,
    'IsPolling': isPolling,
    'PollIntervalMs': pollIntervalMs,
    'Desc': desc,
    'Cdc': cdc,
    'CtlModel': ctlModel,
  };

  factory ClientVariableModel.fromJson(Map<String, dynamic> json) {
    return ClientVariableModel(
      reference: json['Reference'] as String? ?? '',
      iedName: json['IedName'] as String? ?? '',
      ldInst: json['LdInst'] as String? ?? '',
      lnName: json['LnName'] as String? ?? '',
      doName: json['DoName'] as String? ?? '',
      daName: json['DaName'] as String? ?? '',
      fc: FunctionalConstraint.fromCode(json['FC'] as String? ?? 'XX'),
      type: IecBasicType.values.firstWhere(
        (t) => t.name == json['Type'],
        orElse: () => IecBasicType.visibleString,
      ),
      initialValue: json['Value'],
      quality: json['Quality'] as int? ?? 0,
      isMonitored: json['IsMonitored'] as bool? ?? false,
      isPolling: json['IsPolling'] as bool? ?? false,
      pollIntervalMs: json['PollIntervalMs'] as int? ?? 1000,
      desc: json['Desc'] as String?,
      cdc: json['Cdc'] as String?,
      ctlModel: json['CtlModel'] as int?,
    );
  }
}
