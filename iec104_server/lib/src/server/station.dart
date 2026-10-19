import 'dart:math';
import '../i18n/app_i18n.dart';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';
import 'ease_functions.dart';

/// Single Point in a Station Database
class StationPoint {
  final int ioa;
  final AsduTypeId typeId;
  String name;
  String? nameKey;
  dynamic value;
  QualityDescriptor quality;
  DateTime lastUpdated;

  // Auto-simulation configuration
  bool autoChangeEnabled;
  EaseType easeType;
  double easeMin;
  double easeMax;
  double easePeriodSeconds;
  double _elapsedTime;

  StationPoint({
    required this.ioa,
    required this.typeId,
    required this.name,
    this.nameKey,
    required this.value,
    this.quality = QualityDescriptor.good,
    DateTime? lastUpdated,
    this.autoChangeEnabled = false,
    this.easeType = EaseType.sine,
    this.easeMin = 0.0,
    this.easeMax = 100.0,
    this.easePeriodSeconds = 10.0,
  })  : lastUpdated = lastUpdated ?? DateTime.now(),
        _elapsedTime = 0.0;

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  String get displayValue => toInformationObject().displayValue;

  /// Clones this point
  StationPoint copyWith({
    String? name,
    String? nameKey,
    dynamic value,
    QualityDescriptor? quality,
    bool? autoChangeEnabled,
    EaseType? easeType,
    double? easeMin,
    double? easeMax,
    double? easePeriodSeconds,
  }) {
    return StationPoint(
      ioa: ioa,
      typeId: typeId,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      value: value ?? this.value,
      quality: quality ?? this.quality,
      lastUpdated: DateTime.now(),
      autoChangeEnabled: autoChangeEnabled ?? this.autoChangeEnabled,
      easeType: easeType ?? this.easeType,
      easeMin: easeMin ?? this.easeMin,
      easeMax: easeMax ?? this.easeMax,
      easePeriodSeconds: easePeriodSeconds ?? this.easePeriodSeconds,
    );
  }

  /// Steps the auto-simulation clock and calculates new value
  bool tickAutoChange(double deltaSeconds) {
    if (!autoChangeEnabled) return false;
    _elapsedTime += deltaSeconds;

    final newVal = EaseCalculator.calculate(
      type: easeType,
      t: _elapsedTime,
      min: easeMin,
      max: easeMax,
      period: easePeriodSeconds,
    );

    dynamic typedVal;
    switch (typeId) {
      case AsduTypeId.mSpNa1:
      case AsduTypeId.mSpTb1:
        typedVal = newVal >= (easeMin + easeMax) / 2;
        break;

      case AsduTypeId.mDpNa1:
      case AsduTypeId.mDpTb1:
        typedVal = (newVal >= (easeMin + easeMax) / 2) ? 2 : 1;
        break;

      case AsduTypeId.mStNa1:
      case AsduTypeId.mStTb1:
        typedVal = newVal.round().clamp(-64, 63);
        break;

      case AsduTypeId.mBoNa1:
      case AsduTypeId.mBoTb1:
        typedVal = newVal.round().abs() & 0xFFFFFFFF;
        break;

      case AsduTypeId.mMeNa1:
      case AsduTypeId.mMeTd1:
        typedVal = (newVal / max(easeMax.abs(), 1.0)).clamp(-1.0, 1.0);
        break;

      case AsduTypeId.mMeNb1:
      case AsduTypeId.mMeTe1:
        typedVal = newVal.round().clamp(-32768, 32767);
        break;

      case AsduTypeId.mMeNc1:
      case AsduTypeId.mMeTf1:
        typedVal = newVal;
        break;

      case AsduTypeId.mItNa1:
      case AsduTypeId.mItTb1:
        typedVal = (value is int ? value as int : 0) + 1;
        break;

      default:
        typedVal = newVal;
        break;
    }

    if (value != typedVal) {
      value = typedVal;
      lastUpdated = DateTime.now();
      return true;
    }
    return false;
  }

  /// Converts this point to an InformationObject ready for ASDU transmission
  InformationObject toInformationObject({bool withTimestamp = false}) {
    final ts = withTimestamp ? CP56Time2a.now() : null;

    switch (typeId) {
      case AsduTypeId.mSpNa1:
      case AsduTypeId.mSpTb1:
        return SinglePointObject(
          ioa: ioa,
          value: value == true || value == 1,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mDpNa1:
      case AsduTypeId.mDpTb1:
        return DoublePointObject(
          ioa: ioa,
          value: (value is int) ? value : ((value == true || value == 1) ? 2 : 1),
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mStNa1:
      case AsduTypeId.mStTb1:
        return StepPositionObject(
          ioa: ioa,
          value: (value is num) ? (value as num).toInt() : 0,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mBoNa1:
      case AsduTypeId.mBoTb1:
        return Bitstring32Object(
          ioa: ioa,
          value: (value is num) ? (value as num).toInt() : 0,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mMeNa1:
      case AsduTypeId.mMeTd1:
        return MeasuredNormalizedObject(
          ioa: ioa,
          value: (value is num) ? (value as num).toDouble() : 0.0,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mMeNb1:
      case AsduTypeId.mMeTe1:
        return MeasuredScaledObject(
          ioa: ioa,
          value: (value is num) ? (value as num).toInt() : 0,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mMeNc1:
      case AsduTypeId.mMeTf1:
        return MeasuredShortFloatObject(
          ioa: ioa,
          value: (value is num) ? (value as num).toDouble() : 0.0,
          quality: quality,
          timestamp: ts,
        );

      case AsduTypeId.mItNa1:
      case AsduTypeId.mItTb1:
        return IntegratedTotalsObject(
          ioa: ioa,
          counter: (value is num) ? (value as num).toInt() : 0,
          isInvalid: quality.invalid,
          timestamp: ts,
        );

      default:
        return MeasuredShortFloatObject(
          ioa: ioa,
          value: (value is num) ? (value as num).toDouble() : 0.0,
          quality: quality,
          timestamp: ts,
        );
    }
  }

  Map<String, dynamic> toJson() => {
        'ioa': ioa,
        'typeId': typeId.id,
        'name': name,
        'nameKey': nameKey,
        'value': value,
        'quality': quality.toByte(),
        'autoChangeEnabled': autoChangeEnabled,
        'easeType': easeType.name,
        'easeMin': easeMin,
        'easeMax': easeMax,
        'easePeriodSeconds': easePeriodSeconds,
      };

  factory StationPoint.fromJson(Map<String, dynamic> json) {
    final typeId = AsduTypeId.fromId(json['typeId'] as int) ?? AsduTypeId.mMeNc1;
    final ease = EaseType.values.firstWhere(
      (e) => e.name == json['easeType'],
      orElse: () => EaseType.sine,
    );
    final ioa = json['ioa'] as int;
    String? nameKey = json['nameKey'] as String?;
    if (nameKey == null) {
      if (ioa == 1) nameKey = 'point_breaker_101';
      else if (ioa == 2) nameKey = 'point_disconnector_1011';
      else if (ioa == 3) nameKey = 'point_earth_switch_101';
      else if (ioa == 4) nameKey = 'point_station_alarm';
      else if (ioa == 101) nameKey = 'point_breaker_dp';
      else if (ioa == 102) nameKey = 'point_tap_changer_dp';
      else if (ioa == 0x4001) nameKey = 'point_volt_a';
      else if (ioa == 0x4002) nameKey = 'point_volt_b';
      else if (ioa == 0x4003) nameKey = 'point_volt_c';
      else if (ioa == 0x4004) nameKey = 'point_curr_a';
      else if (ioa == 0x4005) nameKey = 'point_active_power';
      else if (ioa == 0x4006) nameKey = 'point_grid_freq';
      else if (ioa == 16400) nameKey = 'point_norm_load';
      else if (ioa == 16401) nameKey = 'point_norm_temp';
      else if (ioa == 16500) nameKey = 'point_oil_temp';
      else if (ioa == 16501) nameKey = 'point_tap_pos';
      else if (ioa == 0x6401) nameKey = 'point_energy_active_fwd';
      else if (ioa == 0x6402) nameKey = 'point_energy_active_rev';
    }

    return StationPoint(
      ioa: ioa,
      typeId: typeId,
      name: json['name'] as String? ?? 'Point',
      nameKey: nameKey,
      value: json['value'],
      quality: QualityDescriptor.fromByte(json['quality'] as int? ?? 0),
      autoChangeEnabled: json['autoChangeEnabled'] as bool? ?? false,
      easeType: ease,
      easeMin: (json['easeMin'] as num?)?.toDouble() ?? 0.0,
      easeMax: (json['easeMax'] as num?)?.toDouble() ?? 100.0,
      easePeriodSeconds: (json['easePeriodSeconds'] as num?)?.toDouble() ?? 10.0,
    );
  }
}

/// Simulated Station / Substation (Common Address of ASDU)
class Station {
  int commonAddress; // COA (1..65535, usually 1)
  String name;
  String? nameKey;
  final Map<int, StationPoint> _points = {};
  void Function()? onDataChanged;

  Station({
    required this.commonAddress,
    required this.name,
    this.nameKey,
    this.onDataChanged,
  });

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  Map<int, StationPoint> get points => Map.unmodifiable(_points);
  List<StationPoint> get pointList => _points.values.toList()..sort((a, b) => a.ioa.compareTo(b.ioa));

  void addPoint(StationPoint point) {
    _points[point.ioa] = point;
    onDataChanged?.call();
  }

  bool removePoint(int ioa) {
    final removed = _points.remove(ioa) != null;
    if (removed) {
      onDataChanged?.call();
    }
    return removed;
  }

  StationPoint? getPoint(int ioa) => _points[ioa];

  bool updatePointValue(int ioa, dynamic newValue, {QualityDescriptor? quality}) {
    final point = _points[ioa];
    if (point != null) {
      bool changed = false;
      if (point.value != newValue) {
        point.value = newValue;
        changed = true;
      }
      if (quality != null && point.quality != quality) {
        point.quality = quality;
        changed = true;
      }
      if (changed) {
        point.lastUpdated = DateTime.now();
        onDataChanged?.call();
      }
      return changed;
    }
    return false;
  }

  /// Batch generates points
  void batchGeneratePoints({
    required AsduTypeId typeId,
    required int startIoa,
    required int count,
    required String prefix,
    dynamic initialValue,
  }) {
    for (int i = 0; i < count; i++) {
      final ioa = startIoa + i;
      dynamic val = initialValue;
      if (val == null) {
        switch (typeId) {
          case AsduTypeId.mSpNa1:
          case AsduTypeId.mSpTb1:
            val = false;
            break;
          case AsduTypeId.mDpNa1:
          case AsduTypeId.mDpTb1:
            val = 1; // 01 = OFF
            break;
          case AsduTypeId.mMeNa1:
          case AsduTypeId.mMeTd1:
            val = 0.0;
            break;
          case AsduTypeId.mMeNb1:
          case AsduTypeId.mMeTe1:
            val = 0;
            break;
          case AsduTypeId.mMeNc1:
          case AsduTypeId.mMeTf1:
            val = 0.0;
            break;
          case AsduTypeId.mItNa1:
          case AsduTypeId.mItTb1:
            val = 0;
            break;
          default:
            val = 0;
        }
      }

      _points[ioa] = StationPoint(
        ioa: ioa,
        typeId: typeId,
        name: '$prefix #$ioa',
        value: val,
      );
    }
    onDataChanged?.call();
  }

  void applyTemplate(String templateKey) {
    if (templateKey == 'distribution') {
      // Distribution Substation Template: 16 YX + 8 YC + 4 DP + 2 YM
      batchGeneratePoints(
        typeId: AsduTypeId.mSpNa1,
        startIoa: 1,
        count: 16,
        prefix: 'Distribution Switch Position',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mDpNa1,
        startIoa: 1001,
        count: 4,
        prefix: 'Feeder Disconnector',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 16385,
        count: 8,
        prefix: 'Feeder Measurand',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mItNa1,
        startIoa: 25601,
        count: 2,
        prefix: 'Energy Meter',
      );
    } else if (templateKey == 'substation') {
      // 110kV Substation Template: 32 YX + 16 YC + 8 DP + 4 YM
      batchGeneratePoints(
        typeId: AsduTypeId.mSpNa1,
        startIoa: 1,
        count: 32,
        prefix: 'Station Breaker',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mDpNa1,
        startIoa: 1001,
        count: 8,
        prefix: 'Earth Switch',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 16385,
        count: 16,
        prefix: '110kV Bus Measurand',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mItNa1,
        startIoa: 25601,
        count: 4,
        prefix: 'Transformer Energy Meter',
      );
    }
  }

  /// Creates a standard default demo substation with realistic points:
  /// - 4 Single Points (遥信)
  /// - 2 Double Points (双位置遥信)
  /// - 6 Float Telemetry (遥测浮点数: 电压、电流、功率、频率)
  /// - 2 Normalized Telemetry (遥测归一化)
  /// - 2 Scaled Telemetry (遥测标度化)
  /// - 2 Integrated Totals (遥脉电能量)
  factory Station.createDefault({int commonAddress = 1, String name = '110kV Substation #1', String? nameKey}) {
    final station = Station(
      commonAddress: commonAddress,
      name: name,
      nameKey: nameKey ?? 'preset_station_110kv',
    );

    // 1. Single-point (M_SP_NA_1 / Type 1) - starting at IOA 1 (0x000001)
    station.addPoint(StationPoint(
      ioa: 1,
      typeId: AsduTypeId.mSpNa1,
      name: 'Breaker 101 Status',
      nameKey: 'point_breaker_101',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 2,
      typeId: AsduTypeId.mSpNa1,
      name: 'Disconnector 1011 Status',
      nameKey: 'point_disconnector_1011',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 3,
      typeId: AsduTypeId.mSpNa1,
      name: 'Earth Switch 101 Status',
      nameKey: 'point_earth_switch_101',
      value: false,
    ));
    station.addPoint(StationPoint(
      ioa: 4,
      typeId: AsduTypeId.mSpNa1,
      name: 'Station General Alarm',
      nameKey: 'point_station_alarm',
      value: false,
    ));

    // 2. Double-point (M_DP_NA_1 / Type 3) - starting at IOA 101
    station.addPoint(StationPoint(
      ioa: 101,
      typeId: AsduTypeId.mDpNa1,
      name: 'Breaker 101 Double Point',
      nameKey: 'point_breaker_dp',
      value: 2, // 10 = ON
    ));
    station.addPoint(StationPoint(
      ioa: 102,
      typeId: AsduTypeId.mDpNa1,
      name: 'Tap Changer Double Point',
      nameKey: 'point_tap_changer_dp',
      value: 2,
    ));

    // 3. Float Telemetry (M_ME_NC_1 / Type 13) - starting at IOA 16385 (0x4001)
    station.addPoint(StationPoint(
      ioa: 0x4001,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase A Voltage Ua (kV)',
      nameKey: 'point_volt_a',
      value: 10.45,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 10.2,
      easeMax: 10.8,
      easePeriodSeconds: 15.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4002,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase B Voltage Ub (kV)',
      nameKey: 'point_volt_b',
      value: 10.48,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 10.2,
      easeMax: 10.8,
      easePeriodSeconds: 15.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4003,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase C Voltage Uc (kV)',
      nameKey: 'point_volt_c',
      value: 10.42,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 10.2,
      easeMax: 10.8,
      easePeriodSeconds: 15.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4004,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase A Current Ia (A)',
      nameKey: 'point_curr_a',
      value: 320.5,
      autoChangeEnabled: true,
      easeType: EaseType.randomWalk,
      easeMin: 300.0,
      easeMax: 350.0,
      easePeriodSeconds: 8.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4005,
      typeId: AsduTypeId.mMeNc1,
      name: 'Active Power P (MW)',
      nameKey: 'point_active_power',
      value: 5.76,
      autoChangeEnabled: true,
      easeType: EaseType.rampUp,
      easeMin: 5.0,
      easeMax: 6.5,
      easePeriodSeconds: 20.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4006,
      typeId: AsduTypeId.mMeNc1,
      name: 'Grid Frequency f (Hz)',
      nameKey: 'point_grid_freq',
      value: 50.02,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 49.95,
      easeMax: 50.05,
      easePeriodSeconds: 10.0,
    ));

    // 4. Normalized Telemetry (M_ME_NA_1 / Type 9) - starting at IOA 16400
    station.addPoint(StationPoint(
      ioa: 16400,
      typeId: AsduTypeId.mMeNa1,
      name: 'Bus Load Rate (Normalized)',
      nameKey: 'point_norm_load',
      value: 0.65,
    ));
    station.addPoint(StationPoint(
      ioa: 16401,
      typeId: AsduTypeId.mMeNa1,
      name: 'Transformer Temp Rise (Normalized)',
      nameKey: 'point_norm_temp',
      value: 0.42,
    ));

    // 5. Scaled Telemetry (M_ME_NB_1 / Type 11) - starting at IOA 16500
    station.addPoint(StationPoint(
      ioa: 16500,
      typeId: AsduTypeId.mMeNb1,
      name: 'Transformer Oil Temp (°C)',
      nameKey: 'point_oil_temp',
      value: 68,
    ));
    station.addPoint(StationPoint(
      ioa: 16501,
      typeId: AsduTypeId.mMeNb1,
      name: 'Tap Position',
      nameKey: 'point_tap_pos',
      value: 5,
    ));

    // 6. Integrated Totals (M_IT_NA_1 / Type 15) - starting at IOA 25601 (0x6401)
    station.addPoint(StationPoint(
      ioa: 0x6401,
      typeId: AsduTypeId.mItNa1,
      name: 'Active Energy + (kWh)',
      nameKey: 'point_energy_active_fwd',
      value: 125890,
      autoChangeEnabled: true,
      easePeriodSeconds: 5.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6402,
      typeId: AsduTypeId.mItNa1,
      name: 'Active Energy - (kWh)',
      nameKey: 'point_energy_active_rev',
      value: 4520,
    ));

    return station;
  }

  factory Station.createDistributionStation({int commonAddress = 2, String name = '10kV Distribution Station #2', String? nameKey}) {
    final station = Station(
      commonAddress: commonAddress,
      name: name,
      nameKey: nameKey ?? 'preset_station_10kv',
    );
    station.addPoint(StationPoint(
      ioa: 1,
      typeId: AsduTypeId.mSpNa1,
      name: 'Breaker 101 Status',
      nameKey: 'point_breaker_101',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 2,
      typeId: AsduTypeId.mSpNa1,
      name: 'Disconnector 1011 Status',
      nameKey: 'point_disconnector_1011',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 101,
      typeId: AsduTypeId.mDpNa1,
      name: 'Breaker 101 Double Point',
      nameKey: 'point_breaker_dp',
      value: 2,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4001,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase A Voltage Ua (kV)',
      nameKey: 'point_volt_a',
      value: 10.38,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 10.1,
      easeMax: 10.7,
      easePeriodSeconds: 12.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4004,
      typeId: AsduTypeId.mMeNc1,
      name: 'Phase A Current Ia (A)',
      nameKey: 'point_curr_a',
      value: 185.2,
      autoChangeEnabled: true,
      easeType: EaseType.randomWalk,
      easeMin: 150.0,
      easeMax: 220.0,
      easePeriodSeconds: 10.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6401,
      typeId: AsduTypeId.mItNa1,
      name: 'Active Energy + (kWh)',
      nameKey: 'point_energy_active_fwd',
      value: 68420,
      autoChangeEnabled: true,
      easePeriodSeconds: 6.0,
    ));
    return station;
  }

  factory Station.createSolarStation({int commonAddress = 3, String name = '35kV Solar Farm Station #3', String? nameKey}) {
    final station = Station(
      commonAddress: commonAddress,
      name: name,
      nameKey: nameKey ?? 'preset_station_solar',
    );
    station.addPoint(StationPoint(
      ioa: 1,
      typeId: AsduTypeId.mSpNa1,
      name: 'PV Inverter Running Status',
      nameKey: 'point_pv_inverter_run',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 2,
      typeId: AsduTypeId.mSpNa1,
      name: 'PV Grid Breaker Status',
      nameKey: 'point_pv_grid_breaker',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4001,
      typeId: AsduTypeId.mMeNc1,
      name: 'Solar Irradiance (W/m²)',
      nameKey: 'point_pv_irradiance',
      value: 860.0,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 200.0,
      easeMax: 1000.0,
      easePeriodSeconds: 20.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4002,
      typeId: AsduTypeId.mMeNc1,
      name: 'PV Power Output (kW)',
      nameKey: 'point_pv_power',
      value: 465.5,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 50.0,
      easeMax: 500.0,
      easePeriodSeconds: 20.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6401,
      typeId: AsduTypeId.mItNa1,
      name: 'PV Daily Yield (kWh)',
      nameKey: 'point_pv_daily_yield',
      value: 3250,
      autoChangeEnabled: true,
      easePeriodSeconds: 10.0,
    ));
    return station;
  }

  factory Station.createStorageStation({int commonAddress = 4, String name = 'Smart Energy Storage BMS #4', String? nameKey}) {
    final station = Station(
      commonAddress: commonAddress,
      name: name,
      nameKey: nameKey ?? 'preset_station_bms',
    );
    station.addPoint(StationPoint(
      ioa: 1,
      typeId: AsduTypeId.mSpNa1,
      name: 'BMS Main Contactor Status',
      nameKey: 'point_bms_cluster_switch',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4001,
      typeId: AsduTypeId.mMeNc1,
      name: 'BMS State of Charge SOC (%)',
      nameKey: 'point_bms_soc',
      value: 78.5,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 20.0,
      easeMax: 95.0,
      easePeriodSeconds: 30.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4002,
      typeId: AsduTypeId.mMeNc1,
      name: 'BMS State of Health SOH (%)',
      nameKey: 'point_bms_soh',
      value: 98.2,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4003,
      typeId: AsduTypeId.mMeNc1,
      name: 'BMS Charge/Discharge Power (kW)',
      nameKey: 'point_bms_power',
      value: 250.0,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: -500.0,
      easeMax: 500.0,
      easePeriodSeconds: 25.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x4004,
      typeId: AsduTypeId.mMeNc1,
      name: 'BMS Cell Max Temperature (°C)',
      nameKey: 'point_bms_cell_temp',
      value: 28.5,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 24.0,
      easeMax: 34.0,
      easePeriodSeconds: 15.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6401,
      typeId: AsduTypeId.mItNa1,
      name: 'BMS Total Charge (kWh)',
      nameKey: 'point_bms_total_charge',
      value: 45280,
      autoChangeEnabled: true,
      easePeriodSeconds: 8.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6402,
      typeId: AsduTypeId.mItNa1,
      name: 'BMS Total Discharge (kWh)',
      nameKey: 'point_bms_total_discharge',
      value: 41200,
    ));
    return station;
  }

  Map<String, dynamic> toJson() => {
        'commonAddress': commonAddress,
        'name': name,
        'nameKey': nameKey,
        'points': _points.values.map((p) => p.toJson()).toList(),
      };

  factory Station.fromJson(Map<String, dynamic> json) {
    final commonAddress = json['commonAddress'] as int? ?? 1;
    final name = json['name'] as String? ?? 'Station';
    String? nameKey = json['nameKey'] as String?;
    if (nameKey == null) {
      if (name.contains('110kV') || commonAddress == 1) {
        nameKey = 'preset_station_110kv';
      } else if (name.contains('10kV') || commonAddress == 2) {
        nameKey = 'preset_station_10kv';
      } else if (name.contains('光伏') || name.contains('Solar') || commonAddress == 3) {
        nameKey = 'preset_station_solar';
      } else if (name.contains('储能') || name.contains('BMS') || commonAddress == 4) {
        nameKey = 'preset_station_bms';
      }
    }

    final station = Station(
      commonAddress: commonAddress,
      name: name,
      nameKey: nameKey,
    );
    final pts = json['points'] as List<dynamic>? ?? [];
    for (final p in pts) {
      final point = StationPoint.fromJson(p as Map<String, dynamic>);
      station.addPoint(point);
    }
    return station;
  }
}
