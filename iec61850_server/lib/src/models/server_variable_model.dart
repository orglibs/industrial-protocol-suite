import 'scl_models.dart';
import 'simulation_config.dart';

class ServerVariableModel {
  final String reference; // e.g. "simpleIO/GenericIO/GGIO1.AnIn1.mag.f"
  final String iedName;
  final String ldInst;
  final String lnName;
  final String doName;
  final String daName;
  final FunctionalConstraint fc;
  final IecBasicType type;

  dynamic _value;
  dynamic get value => _value;
  set value(dynamic v) {
    _value = v;
    timestamp = DateTime.now();
  }

  int quality; // 0 = Good / Valid, 0x01 = Invalid, etc.
  DateTime timestamp;
  SimulationConfig simulation;
  bool isMonitored;
  String? desc;
  int? ctlModel; // For controls: 0=status-only, 1=direct-normal, 2=sbo-normal, 3=direct-enhanced, 4=sbo-enhanced

  ServerVariableModel({
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
    SimulationConfig? simulation,
    this.isMonitored = false,
    this.desc,
    this.ctlModel,
  })  : _value = initialValue ?? _defaultValueForType(type),
        timestamp = timestamp ?? DateTime.now(),
        simulation = simulation ?? SimulationConfig();

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
  String get fcCode => fc.code;

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
    return '疑问 (Questionable 0x${quality.toRadixString(16)})';
  }

  bool setValueFromString(String text) {
    final t = text.trim();
    try {
      switch (type) {
        case IecBasicType.boolean:
          final lower = t.toLowerCase();
          if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on') {
            value = true;
          } else {
            value = false;
          }
          return true;

        case IecBasicType.int8:
        case IecBasicType.int16:
        case IecBasicType.int32:
        case IecBasicType.int64:
        case IecBasicType.uint8:
        case IecBasicType.uint16:
        case IecBasicType.uint32:
          final n = int.tryParse(t);
          if (n != null) {
            value = n;
            return true;
          }
          return false;

        case IecBasicType.float32:
        case IecBasicType.float64:
          final d = double.tryParse(t);
          if (d != null) {
            value = d;
            return true;
          }
          return false;

        default:
          value = t;
          return true;
      }
    } catch (_) {
      return false;
    }
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
    'Desc': desc,
    'CtlModel': ctlModel,
    'Simulation': simulation.toJson(),
  };

  factory ServerVariableModel.fromJson(Map<String, dynamic> json) {
    return ServerVariableModel(
      reference: json['Reference'] as String? ?? '',
      iedName: json['IedName'] as String? ?? '',
      ldInst: json['LdInst'] as String? ?? '',
      lnName: json['LnName'] as String? ?? '',
      doName: json['DoName'] as String? ?? '',
      daName: json['DaName'] as String? ?? '',
      fc: FunctionalConstraint.fromCode(json['FC'] as String? ?? 'ST'),
      type: IecBasicType.fromString(json['Type'] as String? ?? 'VISIBLE_STRING'),
      initialValue: json['Value'],
      quality: json['Quality'] as int? ?? 0,
      isMonitored: json['IsMonitored'] as bool? ?? false,
      desc: json['Desc'] as String?,
      ctlModel: json['CtlModel'] as int?,
      simulation: json['Simulation'] != null
          ? SimulationConfig.fromJson(Map<String, dynamic>.from(json['Simulation']))
          : SimulationConfig(),
    );
  }
}
