import 'scl_models.dart';
import '../i18n/app_i18n.dart';

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
  String? descKey;
  String? get displayDesc {
    if (descKey != null && descKey!.isNotEmpty) {
      final translated = AppI18n.instance.t(descKey!);
      if (translated != descKey) return translated;
    }
    if (desc != null && desc!.isNotEmpty) {
      if (RegExp(r'[\u4e00-\u9fff]').hasMatch(desc!)) {
        final inferred = inferNameKey(
          lnName: lnName,
          doName: doName,
          daName: daName,
          reference: reference,
          name: desc,
          desc: desc,
        );
        if (inferred != null) {
          final translated = AppI18n.instance.t(inferred);
          if (translated != inferred) return translated;
        }
      }
      return desc;
    }
    return null;
  }
  String? cdc;
  int? ctlModel;
  String? name;
  String? nameKey;
  String get displayName {
    if (nameKey != null && nameKey!.isNotEmpty) {
      final translated = AppI18n.instance.t(nameKey!);
      if (translated != nameKey) return translated;
    }
    if (name != null && RegExp(r'[\u4e00-\u9fff]').hasMatch(name!)) {
      final inferred = inferNameKey(
        lnName: lnName,
        doName: doName,
        daName: daName,
        reference: reference,
        name: name,
        desc: desc,
      );
      if (inferred != null) {
        final translated = AppI18n.instance.t(inferred);
        if (translated != inferred) return translated;
      }
    }
    if (name != null && name!.isNotEmpty) return name!;

    final inferred = inferNameKey(
      lnName: lnName,
      doName: doName,
      daName: daName,
      reference: reference,
      name: name,
      desc: desc,
    );
    if (inferred != null) {
      final translated = AppI18n.instance.t(inferred);
      if (translated != inferred) return translated;
    }

    if (displayDesc != null && displayDesc!.isNotEmpty) return displayDesc!;
    return shortRef;
  }

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
    this.descKey,
    this.cdc,
    this.ctlModel,
    this.name,
    this.nameKey,
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

  ClientVariableModel copyWith({
    String? reference,
    String? iedName,
    String? ldInst,
    String? lnName,
    String? doName,
    String? daName,
    FunctionalConstraint? fc,
    IecBasicType? type,
    dynamic value,
    int? quality,
    DateTime? timestamp,
    bool? isMonitored,
    bool? isPolling,
    int? pollIntervalMs,
    String? desc,
    String? descKey,
    String? cdc,
    int? ctlModel,
    String? name,
    String? nameKey,
  }) {
    return ClientVariableModel(
      reference: reference ?? this.reference,
      iedName: iedName ?? this.iedName,
      ldInst: ldInst ?? this.ldInst,
      lnName: lnName ?? this.lnName,
      doName: doName ?? this.doName,
      daName: daName ?? this.daName,
      fc: fc ?? this.fc,
      type: type ?? this.type,
      initialValue: value ?? _value,
      quality: quality ?? this.quality,
      timestamp: timestamp ?? this.timestamp,
      isMonitored: isMonitored ?? this.isMonitored,
      isPolling: isPolling ?? this.isPolling,
      pollIntervalMs: pollIntervalMs ?? this.pollIntervalMs,
      desc: desc ?? this.desc,
      descKey: descKey ?? this.descKey,
      cdc: cdc ?? this.cdc,
      ctlModel: ctlModel ?? this.ctlModel,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
    );
  }

  static String? inferNameKey({
    required String lnName,
    required String doName,
    required String daName,
    String? reference,
    String? name,
    String? desc,
  }) {
    // 0. Chinese name or description matching
    final text = '${name ?? ''} ${desc ?? ''}';
    if (text.trim().isNotEmpty) {
      if (text.contains('1#进线') || text.contains('1号进线') || text.contains('进线开关1') || text.contains('Feeder #1')) {
        return 'point_feeder_switch_1';
      }
      if (text.contains('2#进线') || text.contains('2号进线') || text.contains('进线开关2') || text.contains('Feeder #2')) {
        return 'point_feeder_switch_2';
      }
      if (text.contains('3#出线') || text.contains('3号出线') || text.contains('Feeder #3')) {
        return 'point_feeder_switch_3';
      }
      if (text.contains('4#出线') || text.contains('4号出线') || text.contains('Feeder #4')) {
        return 'point_feeder_switch_4';
      }
      if (text.contains('5#出线') || text.contains('5号出线') || text.contains('母联') || text.contains('分段') || text.contains('Feeder #5')) {
        return 'point_feeder_switch_5';
      }
      if (text.contains('6#出线') || text.contains('6号出线') || text.contains('Feeder #6')) {
        return 'point_feeder_switch_6';
      }
      if (text.contains('7#出线') || text.contains('7号出线') || text.contains('Feeder #7')) {
        return 'point_feeder_switch_7';
      }
      if (text.contains('8#出线') || text.contains('8号出线') || text.contains('Feeder #8')) {
        return 'point_feeder_switch_8';
      }
      if (text.contains('9#出线') || text.contains('9号出线') || text.contains('Feeder #9')) {
        return 'point_feeder_switch_9';
      }
      if (text.contains('101断路器') || text.contains('出线断路器') || text.contains('断路器') || text.contains('101开关') || text.contains('Breaker 101')) {
        return 'point_breaker_101';
      }
      if (text.contains('1011隔离开关') || text.contains('隔离开关') || text.contains('隔离刀闸') || text.contains('1011刀闸') || text.contains('Disconnector 1011')) {
        return 'point_disconnector_1011';
      }
      if (text.contains('接地刀闸') || text.contains('接地开关') || text.contains('Earth Switch')) {
        return 'point_earth_switch_101';
      }
      if (text.contains('保护') || text.contains('跳闸') || text.contains('Trip') || text.contains('速断') || text.contains('过流')) {
        if (text.contains('品质') || text.contains('Quality')) return 'point_trip_quality';
        if (text.contains('时标') || text.contains('时间') || text.contains('Timestamp')) return 'point_trip_time';
        return 'point_protection_trip';
      }
      if (text.contains('A相电压') || text.contains('Phase A Voltage') || text.contains('Ua')) return 'point_volt_a';
      if (text.contains('B相电压') || text.contains('Phase B Voltage') || text.contains('Ub')) return 'point_volt_b';
      if (text.contains('C相电压') || text.contains('Phase C Voltage') || text.contains('Uc')) return 'point_volt_c';
      if (text.contains('A相电流') || text.contains('Phase A Current') || text.contains('Ia')) return 'point_curr_a';
      if (text.contains('B相电流') || text.contains('Phase B Current') || text.contains('Ib')) return 'point_curr_b';
      if (text.contains('C相电流') || text.contains('Phase C Current') || text.contains('Ic')) return 'point_curr_c';
      if (text.contains('有功功率') || text.contains('Active Power')) return 'point_active_power';
      if (text.contains('无功功率') || text.contains('Reactive Power')) return 'point_reactive_power';
      if (text.contains('功率因数') || text.contains('Power Factor')) return 'point_power_factor';
      if (text.contains('频率') || text.contains('Frequency')) return 'point_grid_freq';
      if (text.contains('正向有功') || text.contains('有功总电能') || text.contains('Active Energy')) return 'point_energy_active_fwd';
      if (text.contains('油温') || text.contains('Oil Temp')) return 'point_oil_temp';
      if (text.contains('档位') || text.contains('Tap Position')) return 'point_tap_pos';
      if (text.contains('负荷率') || text.contains('Load')) return 'point_norm_load';
      if (text.contains('温升') || text.contains('Temp')) return 'point_norm_temp';
      if (text.contains('运行状态') || text.contains('装置运行') || text.contains('Running')) return 'point_device_run';
      if (text.contains('全站告警') || text.contains('事故总告警') || text.contains('Station Alarm')) return 'point_station_alarm';
      if (text.contains('远方联锁') || text.contains('遥控闭锁') || text.contains('Interlock')) return 'point_remote_interlock';
      if (text.contains('系统故障') || text.contains('故障告警') || text.contains('Fault Alarm')) return 'point_fault_alarm';
      if (text.contains('运行模式') || text.contains('控制模式')) return 'point_mode';
      if (text.contains('运行行为')) return 'point_behaviour';
      if (text.contains('设备健康') || text.contains('健康度')) return 'point_health';
      if (text.contains('物理健康')) return 'point_phy_health';
      if (text.contains('铭牌')) return 'point_nameplate';
    }

    final ln = lnName.toUpperCase();
    final dName = doName.toUpperCase();
    final aName = daName.toUpperCase();

    // 1. GGIO / Generic IO Points
    if (ln.contains('GGIO')) {
      if (dName == 'SPCSO1') return 'point_feeder_switch_1';
      if (dName == 'SPCSO2') return 'point_feeder_switch_2';
      if (dName == 'SPCSO3') return 'point_feeder_switch_3';
      if (dName == 'SPCSO4') return 'point_feeder_switch_4';
      if (dName == 'SPCSO5') return 'point_feeder_switch_5';
      if (dName == 'SPCSO6') return 'point_feeder_switch_6';
      if (dName == 'SPCSO7') return 'point_feeder_switch_7';
      if (dName == 'SPCSO8') return 'point_feeder_switch_8';
      if (dName == 'SPCSO9') return 'point_feeder_switch_9';
      if (dName == 'ANIN1') return 'point_volt_a';
      if (dName == 'ANIN2') return 'point_volt_b';
      if (dName == 'ANIN3') return 'point_curr_a';
      if (dName == 'ANIN4') return 'point_active_power';
      if (dName == 'IND1') return 'point_device_run';
      if (dName == 'IND2') return 'point_station_alarm';
      if (dName == 'IND3') return 'point_remote_interlock';
      if (dName == 'IND4') return 'point_fault_alarm';
    }

    // 2. Measurements (MMXU / MMTN)
    if (ln.contains('MMXU') || ln.contains('MMTN')) {
      if (dName == 'TOTW') return 'point_active_power';
      if (dName == 'TOTVAR') return 'point_reactive_power';
      if (dName == 'TOTPF') return 'point_power_factor';
      if (dName == 'HZ') return 'point_grid_freq';
      if (dName == 'PHV') {
        if (aName.contains('PHSA')) return 'point_volt_a';
        if (aName.contains('PHSB')) return 'point_volt_b';
        if (aName.contains('PHSC')) return 'point_volt_c';
        return 'point_volt_a';
      }
      if (dName == 'A') {
        if (aName.contains('PHSA')) return 'point_curr_a';
        if (aName.contains('PHSB')) return 'point_curr_b';
        if (aName.contains('PHSC')) return 'point_curr_c';
        return 'point_curr_a';
      }
      if (dName == 'TOTWH') return 'point_energy_active_fwd';
    }

    // 3. Switchgear & Breakers (XCBR, CSWI, XSWI)
    if (ln.contains('XCBR') || ln.contains('CSWI')) {
      if (dName == 'POS') return 'point_breaker_101';
    }
    if (ln.contains('XSWI')) {
      if (dName == 'POS') return 'point_disconnector_1011';
    }

    // 4. Protection (PTRC, PIOC, PTOC)
    if (ln.contains('PTRC') || ln.contains('PIOC') || ln.contains('PTOC')) {
      if (dName == 'TR') {
        if (aName.contains('GENERAL')) return 'point_protection_trip';
        if (aName == 'Q') return 'point_trip_quality';
        if (aName == 'T') return 'point_trip_time';
        return 'point_protection_trip';
      }
    }

    // 5. Common Logical Node Data Objects
    if (dName == 'MOD') return 'point_mode';
    if (dName == 'BEH') return 'point_behaviour';
    if (dName == 'HEALTH') return 'point_health';
    if (dName == 'PHYHEALTH') return 'point_phy_health';
    if (dName == 'NAMPLT') return 'point_nameplate';

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
    'Value': _value,
    'Quality': quality,
    'IsMonitored': isMonitored,
    'IsPolling': isPolling,
    'PollIntervalMs': pollIntervalMs,
    'Desc': desc,
    'DescKey': descKey,
    'Cdc': cdc,
    'CtlModel': ctlModel,
    'Name': name,
    'NameKey': nameKey,
  };

  factory ClientVariableModel.fromJson(Map<String, dynamic> json) {
    final ref = (json['Reference'] ?? json['reference']) as String? ?? '';
    final iedName = (json['IedName'] ?? json['iedName']) as String? ?? '';
    final ldInst = (json['LdInst'] ?? json['ldInst']) as String? ?? '';
    final lnName = (json['LnName'] ?? json['lnName']) as String? ?? '';
    final doName = (json['DoName'] ?? json['doName']) as String? ?? '';
    final daName = (json['DaName'] ?? json['daName']) as String? ?? '';
    final name = (json['Name'] ?? json['name']) as String?;
    final desc = (json['Desc'] ?? json['desc']) as String?;
    String? nameKey = (json['NameKey'] ?? json['nameKey']) as String?;

    if (nameKey == null || nameKey.isEmpty) {
      nameKey = inferNameKey(
        lnName: lnName,
        doName: doName,
        daName: daName,
        reference: ref,
        name: name,
        desc: desc,
      );
    }

    return ClientVariableModel(
      reference: ref,
      iedName: iedName,
      ldInst: ldInst,
      lnName: lnName,
      doName: doName,
      daName: daName,
      fc: FunctionalConstraint.fromCode((json['FC'] ?? json['fc']) as String? ?? 'XX'),
      type: IecBasicType.values.firstWhere(
        (t) => t.name == (json['Type'] ?? json['type']),
        orElse: () => IecBasicType.visibleString,
      ),
      initialValue: json['Value'] ?? json['value'],
      quality: (json['Quality'] ?? json['quality']) as int? ?? 0,
      isMonitored: (json['IsMonitored'] ?? json['isMonitored']) as bool? ?? false,
      isPolling: (json['IsPolling'] ?? json['isPolling']) as bool? ?? false,
      pollIntervalMs: (json['PollIntervalMs'] ?? json['pollIntervalMs']) as int? ?? 1000,
      desc: (json['Desc'] ?? json['desc']) as String?,
      descKey: (json['DescKey'] ?? json['descKey']) as String?,
      cdc: (json['Cdc'] ?? json['cdc']) as String?,
      ctlModel: (json['CtlModel'] ?? json['ctlModel']) as int?,
      name: name,
      nameKey: nameKey,
    );
  }
}
