import 'scl_models.dart';
import 'simulation_config.dart';
import 'dictionary_service.dart';
import '../i18n/app_i18n.dart';

class ServerVariableModel {
  final String reference; // e.g. "simpleIO/GenericIO/GGIO1.AnIn1.mag.f"
  final String iedName;
  final String ldInst;
  final String lnName;
  final String doName;
  final String daName;
  final FunctionalConstraint fc;
  final IecBasicType type;
  final String? cdc;

  String? name;
  String? nameKey;
  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : (name != null && name!.isNotEmpty ? name! : shortRef);

  String? get cdcDisplay {
    final code = cdc ?? DictionaryService.instance.getDataObject(doName)?.cdc;
    if (code == null) return null;
    final desc = DictionaryService.instance.getCdc(code);
    return desc != null ? '$code (${desc.display})' : code;
  }

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
  String? descKey;
  String? get displayDesc => (descKey != null && descKey!.isNotEmpty)
      ? AppI18n.instance.t(descKey!)
      : desc;
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
    this.cdc,
    this.name,
    this.nameKey,
    dynamic initialValue,
    this.quality = 0,
    DateTime? timestamp,
    SimulationConfig? simulation,
    this.isMonitored = false,
    this.desc,
    this.descKey,
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
    if (quality == 0) return AppI18n.instance.t('qualityGood');
    if ((quality & 0x01) != 0) return AppI18n.instance.t('qualityInvalid');
    if ((quality & 0x02) != 0) return AppI18n.instance.t('qualityOverflow');
    if ((quality & 0x04) != 0) return AppI18n.instance.t('qualityOutOfRange');
    if ((quality & 0x08) != 0) return AppI18n.instance.t('qualityBadRef');
    if ((quality & 0x10) != 0) return AppI18n.instance.t('qualityOscillatory');
    if ((quality & 0x20) != 0) return AppI18n.instance.t('qualityFailure');
    if ((quality & 0x40) != 0) return AppI18n.instance.t('qualityOldData');
    if ((quality & 0x2000) != 0) return AppI18n.instance.t('qualityTest');
    if ((quality & 0x4000) != 0) return AppI18n.instance.t('qualityBlocked');
    return '${AppI18n.instance.t("qualityQuestionable")} (0x${quality.toRadixString(16)})';
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

  ServerVariableModel copyWith({
    String? reference,
    String? iedName,
    String? ldInst,
    String? lnName,
    String? doName,
    String? daName,
    FunctionalConstraint? fc,
    IecBasicType? type,
    String? cdc,
    String? name,
    String? nameKey,
    dynamic value,
    int? quality,
    DateTime? timestamp,
    SimulationConfig? simulation,
    bool? isMonitored,
    String? desc,
    String? descKey,
    int? ctlModel,
  }) {
    return ServerVariableModel(
      reference: reference ?? this.reference,
      iedName: iedName ?? this.iedName,
      ldInst: ldInst ?? this.ldInst,
      lnName: lnName ?? this.lnName,
      doName: doName ?? this.doName,
      daName: daName ?? this.daName,
      fc: fc ?? this.fc,
      type: type ?? this.type,
      cdc: cdc ?? this.cdc,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      initialValue: value ?? _value,
      quality: quality ?? this.quality,
      timestamp: timestamp ?? this.timestamp,
      simulation: simulation ?? this.simulation,
      isMonitored: isMonitored ?? this.isMonitored,
      desc: desc ?? this.desc,
      descKey: descKey ?? this.descKey,
      ctlModel: ctlModel ?? this.ctlModel,
    );
  }

  static String? inferNameKey({
    required String doName,
    String daName = '',
    String lnName = '',
    String ref = '',
  }) {
    final d = doName.toLowerCase();
    final da = daName.toLowerCase();
    final ln = lnName.toLowerCase();
    final r = ref.toLowerCase();

    // 1. Voltages
    if (d == 'anin1' || d.contains('phv') || d.contains('ppv') || d.contains('vol')) {
      if (da.contains('phsb') || d.contains('phsb')) return 'point_volt_b';
      if (da.contains('phsc') || d.contains('phsc')) return 'point_volt_c';
      return 'point_volt_a';
    }

    // 2. Currents
    if (d == 'anin2' || d.startsWith('amp') || d == 'a') {
      if (da.contains('phsb') || d.contains('phsb')) return 'point_curr_b';
      if (da.contains('phsc') || d.contains('phsc')) return 'point_curr_c';
      return 'point_curr_a';
    }

    // 3. Powers & Frequency
    if (d == 'anin3' || d.contains('totw') || d == 'w') {
      return 'point_active_power';
    }
    if (d.contains('totvar') || d == 'var') {
      return 'point_reactive_power';
    }
    if (d.contains('totpf') || d == 'pf') {
      return 'point_power_factor';
    }
    if (d == 'anin4' || d == 'hz') {
      return 'point_grid_freq';
    }

    // 4. Energy
    if (d.contains('totwh')) return 'point_energy_active_fwd';
    if (d.contains('totvarh')) return 'point_energy_active_rev';

    // 5. Switches & Breakers
    if (d == 'spcso1' || d == 'ind1') return 'point_breaker_101';
    if (d == 'spcso2' || d == 'ind2') return 'point_disconnector_1011';
    if (d == 'spcso3' || d == 'ind3') return 'point_earth_switch_101';
    if (d == 'spcso4' || d == 'ind4') return 'point_station_alarm';
    if (d.contains('pos') || ln.contains('xcbr') || ln.contains('cswi')) return 'point_breaker_dp';

    // 6. Generic Device Nodes
    if (d == 'mod') return 'point_device_mode';
    if (d == 'beh') return 'point_device_beh';
    if (d == 'health' || d == 'phyhealth') return 'point_device_health';

    // 7. Wind & Generator Nodes (IEC 61400-25)
    if (d == 'rotspd' || d == 'wrot') return 'point_rotor_speed';
    if (d == 'windspd') return 'point_wind_speed';
    if (d == 'pitch') return 'point_pitch_angle';
    if (d == 'genspd') return 'point_gen_speed';

    // 8. Search in Reference string
    if (r.contains('anin1')) return 'point_volt_a';
    if (r.contains('anin2')) return 'point_curr_a';
    if (r.contains('anin3')) return 'point_active_power';
    if (r.contains('anin4')) return 'point_grid_freq';
    if (r.contains('spcso1') || r.contains('ind1')) return 'point_breaker_101';
    if (r.contains('spcso2') || r.contains('ind2')) return 'point_disconnector_1011';
    if (r.contains('spcso3') || r.contains('ind3')) return 'point_earth_switch_101';
    if (r.contains('spcso4') || r.contains('ind4')) return 'point_station_alarm';

    return null;
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
    'CDC': cdc,
    'Name': name,
    'NameKey': nameKey,
    'Value': _value,
    'Quality': quality,
    'IsMonitored': isMonitored,
    'Desc': desc,
    'DescKey': descKey,
    'CtlModel': ctlModel,
    'Simulation': simulation.toJson(),
  };

  factory ServerVariableModel.fromJson(Map<String, dynamic> json) {
    final doName = json['DoName'] as String? ?? '';
    final daName = json['DaName'] as String? ?? '';
    final lnName = json['LnName'] as String? ?? '';
    final ref = json['Reference'] as String? ?? '';
    final name = json['Name'] as String? ?? json['name'] as String?;
    String? nameKey = json['NameKey'] as String? ?? json['nameKey'] as String?;
    if (nameKey == null || nameKey.isEmpty) {
      nameKey = inferNameKey(doName: doName, daName: daName, lnName: lnName, ref: ref);
    }

    return ServerVariableModel(
      reference: ref,
      iedName: json['IedName'] as String? ?? '',
      ldInst: json['LdInst'] as String? ?? '',
      lnName: lnName,
      doName: doName,
      daName: daName,
      fc: FunctionalConstraint.fromCode(json['FC'] as String? ?? 'ST'),
      type: IecBasicType.fromString(json['Type'] as String? ?? 'VISIBLE_STRING'),
      cdc: json['CDC'] as String? ?? json['cdc'] as String?,
      name: name,
      nameKey: nameKey,
      initialValue: json['Value'],
      quality: json['Quality'] as int? ?? 0,
      isMonitored: json['IsMonitored'] as bool? ?? false,
      desc: json['Desc'] as String?,
      descKey: json['DescKey'] as String? ?? json['descKey'] as String?,
      ctlModel: json['CtlModel'] as int?,
      simulation: json['Simulation'] != null
          ? SimulationConfig.fromJson(Map<String, dynamic>.from(json['Simulation']))
          : SimulationConfig(),
    );
  }
}
