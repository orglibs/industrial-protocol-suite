import 'dart:math';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';
import 'ease_functions.dart';

/// Single Point in a Station Database
class StationPoint {
  final int ioa;
  final AsduTypeId typeId;
  String name;
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

  String get displayValue => toInformationObject().displayValue;

  /// Clones this point
  StationPoint copyWith({
    String? name,
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
    return StationPoint(
      ioa: json['ioa'] as int,
      typeId: typeId,
      name: json['name'] as String? ?? 'Point',
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
  final Map<int, StationPoint> _points = {};
  void Function()? onDataChanged;

  Station({
    required this.commonAddress,
    required this.name,
    this.onDataChanged,
  });

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
      // 典型配网模板: 16 YX + 8 YC + 4 DP + 2 YM
      batchGeneratePoints(
        typeId: AsduTypeId.mSpNa1,
        startIoa: 1,
        count: 16,
        prefix: '配电开关分合位置',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mDpNa1,
        startIoa: 1001,
        count: 4,
        prefix: '出线隔离刀闸双位置',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 16385,
        count: 8,
        prefix: '出线遥测负荷电压电流',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mItNa1,
        startIoa: 25601,
        count: 2,
        prefix: '关口进线电能量表',
      );
    } else if (templateKey == 'substation') {
      // 典型变电站模板: 32 YX + 16 YC + 8 DP + 4 YM
      batchGeneratePoints(
        typeId: AsduTypeId.mSpNa1,
        startIoa: 1,
        count: 32,
        prefix: '站内断路器位置遥信',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mDpNa1,
        startIoa: 1001,
        count: 8,
        prefix: '接地刀闸双点遥信',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 16385,
        count: 16,
        prefix: '110kV母线电压频率遥测',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mItNa1,
        startIoa: 25601,
        count: 4,
        prefix: '主变侧关口电能量',
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
  factory Station.createDefault({int commonAddress = 1, String name = '110kV 变电站 #1'}) {
    final station = Station(commonAddress: commonAddress, name: name);

    // 1. Single-point (遥信 M_SP_NA_1 / Type 1) - starting at IOA 1 (0x000001)
    station.addPoint(StationPoint(
      ioa: 1,
      typeId: AsduTypeId.mSpNa1,
      name: '101断路器合闸状态 (Breaker 101)',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 2,
      typeId: AsduTypeId.mSpNa1,
      name: '1011隔离开关分合 (Disconnector 1011)',
      value: true,
    ));
    station.addPoint(StationPoint(
      ioa: 3,
      typeId: AsduTypeId.mSpNa1,
      name: '101接地刀闸状态 (Earth Switch 101)',
      value: false,
    ));
    station.addPoint(StationPoint(
      ioa: 4,
      typeId: AsduTypeId.mSpNa1,
      name: '全站事故总告警 (Station Alarm)',
      value: false,
    ));

    // 2. Double-point (双点遥信 M_DP_NA_1 / Type 3) - starting at IOA 101
    station.addPoint(StationPoint(
      ioa: 101,
      typeId: AsduTypeId.mDpNa1,
      name: '主变101开关双位置 (Breaker Double Point)',
      value: 2, // 10 = 合/ON
    ));
    station.addPoint(StationPoint(
      ioa: 102,
      typeId: AsduTypeId.mDpNa1,
      name: '有载调压开关状态 (Tap Changer Double)',
      value: 2,
    ));

    // 3. Float Telemetry (遥测短浮点 M_ME_NC_1 / Type 13) - starting at IOA 16385 (0x4001)
    station.addPoint(StationPoint(
      ioa: 0x4001,
      typeId: AsduTypeId.mMeNc1,
      name: 'A相电压 Ua (kV)',
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
      name: 'B相电压 Ub (kV)',
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
      name: 'C相电压 Uc (kV)',
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
      name: 'A相电流 Ia (A)',
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
      name: '有功功率 P (MW)',
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
      name: '电网频率 f (Hz)',
      value: 50.02,
      autoChangeEnabled: true,
      easeType: EaseType.sine,
      easeMin: 49.95,
      easeMax: 50.05,
      easePeriodSeconds: 10.0,
    ));

    // 4. Normalized Telemetry (归一化 M_ME_NA_1 / Type 9) - starting at IOA 16400
    station.addPoint(StationPoint(
      ioa: 16400,
      typeId: AsduTypeId.mMeNa1,
      name: '母线负荷率 (Normalized Load)',
      value: 0.65,
    ));
    station.addPoint(StationPoint(
      ioa: 16401,
      typeId: AsduTypeId.mMeNa1,
      name: '变压器温升 (Normalized Temp)',
      value: 0.42,
    ));

    // 5. Scaled Telemetry (标度化 M_ME_NB_1 / Type 11) - starting at IOA 16500
    station.addPoint(StationPoint(
      ioa: 16500,
      typeId: AsduTypeId.mMeNb1,
      name: '变压器油温 (°C)',
      value: 68,
    ));
    station.addPoint(StationPoint(
      ioa: 16501,
      typeId: AsduTypeId.mMeNb1,
      name: '主变档位 (Tap Position)',
      value: 5,
    ));

    // 6. Integrated Totals (电能量遥脉 M_IT_NA_1 / Type 15) - starting at IOA 25601 (0x6401)
    station.addPoint(StationPoint(
      ioa: 0x6401,
      typeId: AsduTypeId.mItNa1,
      name: '正向有功总电能 (Active Energy + kWh)',
      value: 125890,
      autoChangeEnabled: true,
      easePeriodSeconds: 5.0,
    ));
    station.addPoint(StationPoint(
      ioa: 0x6402,
      typeId: AsduTypeId.mItNa1,
      name: '反向有功总电能 (Active Energy - kWh)',
      value: 4520,
    ));

    return station;
  }

  Map<String, dynamic> toJson() => {
        'commonAddress': commonAddress,
        'name': name,
        'points': _points.values.map((p) => p.toJson()).toList(),
      };

  factory Station.fromJson(Map<String, dynamic> json) {
    final station = Station(
      commonAddress: json['commonAddress'] as int? ?? 1,
      name: json['name'] as String? ?? 'Station',
    );
    final pts = json['points'] as List<dynamic>? ?? [];
    for (final p in pts) {
      final point = StationPoint.fromJson(p as Map<String, dynamic>);
      station.addPoint(point);
    }
    return station;
  }
}
