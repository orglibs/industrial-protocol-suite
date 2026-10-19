import '../i18n/app_i18n.dart';
import '../protocol/asdu.dart';
import '../protocol/asdu_types.dart';

class PointHistoryEntry {
  final DateTime time;
  final dynamic value;
  final QualityDescriptor? quality;

  PointHistoryEntry({
    required this.time,
    required this.value,
    this.quality,
  });
}

class ClientPointModel {
  final int commonAddress;
  final int ioa;
  final AsduTypeId typeId;
  String name;
  String? nameKey;
  dynamic value;
  QualityDescriptor? quality;
  DateTime lastUpdated;
  int updateCount;
  final List<PointHistoryEntry> history = [];

  ClientPointModel({
    required this.commonAddress,
    required this.ioa,
    required this.typeId,
    required this.name,
    this.nameKey,
    required this.value,
    this.quality,
    DateTime? lastUpdated,
    this.updateCount = 1,
  }) : lastUpdated = lastUpdated ?? DateTime.now() {
    recordHistory(value, quality, this.lastUpdated);
  }

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  void update(dynamic newVal, QualityDescriptor? newQuality, [DateTime? time]) {
    value = newVal;
    quality = newQuality;
    lastUpdated = time ?? DateTime.now();
    updateCount++;
    recordHistory(newVal, newQuality, lastUpdated);
  }

  void recordHistory(dynamic v, QualityDescriptor? q, DateTime t) {
    history.add(PointHistoryEntry(time: t, value: v, quality: q));
    if (history.length > 100) {
      history.removeAt(0);
    }
  }

  String get displayValue {
    final i18n = AppI18n.instance;
    if (value is bool) {
      return value ? i18n.t('spStateOn') : i18n.t('spStateOff');
    } else if (value is double) {
      return (value as double).toStringAsFixed(2);
    } else if (value is int) {
      if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
        return value == 2
            ? i18n.t('dpStateOn')
            : (value == 1 ? i18n.t('dpStateOff') : (value == 3 ? i18n.t('dpStateFault') : i18n.t('dpStateIndeterminate')));
      }
      return value.toString();
    }
    return value.toString();
  }

  String get typeCategory {
    final i18n = AppI18n.instance;
    if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) return i18n.t('pointTypeSp');
    if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) return i18n.t('pointTypeDp');
    if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) return i18n.t('pointTypeMeNc');
    if (typeId == AsduTypeId.mMeNa1 || typeId == AsduTypeId.mMeTd1) return i18n.t('pointTypeMeNa');
    if (typeId == AsduTypeId.mMeNb1 || typeId == AsduTypeId.mMeTe1) return i18n.t('pointTypeMeNb');
    if (typeId == AsduTypeId.mItNa1 || typeId == AsduTypeId.mItTb1) return i18n.t('pointTypeIt');
    if (typeId == AsduTypeId.mStNa1 || typeId == AsduTypeId.mStTb1) return i18n.t('pointTypeSt');
    if (typeId == AsduTypeId.mBoNa1 || typeId == AsduTypeId.mBoTb1) return i18n.t('pointTypeBo');
    return i18n.t('pointTypeOther');
  }

  Map<String, dynamic> toJson() => {
        'ioa': ioa,
        'typeId': typeId.id,
        'name': name,
        'nameKey': nameKey,
        'value': value,
      };

  static ClientPointModel fromJson(int ca, Map<String, dynamic> json) {
    final typeIdInt = json['typeId'] as int? ?? AsduTypeId.mMeNc1.id;
    final typeId = AsduTypeId.fromId(typeIdInt) ?? AsduTypeId.mMeNc1;
    final ioa = json['ioa'] as int? ?? 1;
    final name = json['name'] as String? ?? 'Point #$ioa';
    final val = json['value'];
    String? nameKey = json['nameKey'] as String? ?? json['NameKey'] as String?;

    if (nameKey == null) {
      if (ioa == 1) {
        nameKey = 'point_breaker_101';
      } else if (ioa == 2) {
        nameKey = 'point_disconnector_1011';
      } else if (ioa == 3) {
        nameKey = 'point_earth_switch_101';
      } else if (ioa == 4) {
        nameKey = 'point_station_alarm';
      } else if (ioa == 101) {
        nameKey = 'point_breaker_dp';
      } else if (ioa == 102) {
        nameKey = 'point_tap_changer_dp';
      } else if (ioa == 0x4001 || ioa == 16385) {
        nameKey = 'point_volt_a';
      } else if (ioa == 0x4002 || ioa == 16386) {
        nameKey = 'point_volt_b';
      } else if (ioa == 0x4003 || ioa == 16387) {
        nameKey = 'point_volt_c';
      } else if (ioa == 0x4004 || ioa == 16388) {
        nameKey = 'point_curr_a';
      } else if (ioa == 0x4005 || ioa == 16389) {
        nameKey = 'point_active_power';
      } else if (ioa == 0x4006 || ioa == 16390) {
        nameKey = 'point_grid_freq';
      } else if (ioa == 16400) {
        nameKey = 'point_norm_load';
      } else if (ioa == 16401) {
        nameKey = 'point_norm_temp';
      } else if (ioa == 16500) {
        nameKey = 'point_oil_temp';
      } else if (ioa == 16501) {
        nameKey = 'point_tap_pos';
      } else if (ioa == 0x6401 || ioa == 25601) {
        nameKey = 'point_energy_active_fwd';
      } else if (ioa == 0x6402 || ioa == 25602) {
        nameKey = 'point_energy_active_rev';
      }
    }

    return ClientPointModel(
      commonAddress: ca,
      ioa: ioa,
      typeId: typeId,
      name: name,
      nameKey: nameKey,
      value: val ?? (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1 ? false : 0.0),
    );
  }
}

class ClientStationModel {
  int commonAddress;
  String name;
  String? nameKey;
  final Map<int, ClientPointModel> points = {};
  void Function()? onDataChanged;

  ClientStationModel({
    required this.commonAddress,
    this.name = '',
    this.nameKey,
    this.onDataChanged,
  }) {
    if (name.isEmpty) {
      name = 'Station (CA=$commonAddress)';
    }
  }

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  List<ClientPointModel> get pointList => points.values.toList()..sort((a, b) => a.ioa.compareTo(b.ioa));

  ClientPointModel? getPoint(int ioa) => points[ioa];

  void addPoint(ClientPointModel point) {
    points[point.ioa] = point;
    onDataChanged?.call();
  }

  bool removePoint(int ioa) {
    final removed = points.remove(ioa) != null;
    if (removed) {
      onDataChanged?.call();
    }
    return removed;
  }

  void batchGeneratePoints({
    required AsduTypeId typeId,
    required int startIoa,
    required int count,
    required String prefix,
    dynamic defaultValue,
  }) {
    for (int i = 0; i < count; i++) {
      final ioa = startIoa + i;
      dynamic val = defaultValue;
      if (val == null) {
        if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) {
          val = false;
        } else if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
          val = 1; // 01: OFF
        } else if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) {
          val = 0.0;
        } else if (typeId == AsduTypeId.mMeNa1 || typeId == AsduTypeId.mMeTd1) {
          val = 0;
        } else if (typeId == AsduTypeId.mMeNb1 || typeId == AsduTypeId.mMeTe1) {
          val = 0;
        } else if (typeId == AsduTypeId.mItNa1 || typeId == AsduTypeId.mItTb1) {
          val = 0;
        } else {
          val = 0;
        }
      }

      String? key;
      if (ioa == 1) {
        key = 'point_breaker_101';
      } else if (ioa == 2) {
        key = 'point_disconnector_1011';
      } else if (ioa == 3) {
        key = 'point_earth_switch_101';
      } else if (ioa == 4) {
        key = 'point_station_alarm';
      } else if (ioa == 101) {
        key = 'point_breaker_dp';
      } else if (ioa == 102) {
        key = 'point_tap_changer_dp';
      } else if (ioa == 0x4001 || ioa == 16385) {
        key = 'point_volt_a';
      } else if (ioa == 0x4002 || ioa == 16386) {
        key = 'point_volt_b';
      } else if (ioa == 0x4003 || ioa == 16387) {
        key = 'point_volt_c';
      } else if (ioa == 0x4004 || ioa == 16388) {
        key = 'point_curr_a';
      } else if (ioa == 0x4005 || ioa == 16389) {
        key = 'point_active_power';
      } else if (ioa == 0x4006 || ioa == 16390) {
        key = 'point_grid_freq';
      } else if (ioa == 16400) {
        key = 'point_norm_load';
      } else if (ioa == 16401) {
        key = 'point_norm_temp';
      } else if (ioa == 16500) {
        key = 'point_oil_temp';
      } else if (ioa == 16501) {
        key = 'point_tap_pos';
      } else if (ioa == 0x6401 || ioa == 25601) {
        key = 'point_energy_active_fwd';
      } else if (ioa == 0x6402 || ioa == 25602) {
        key = 'point_energy_active_rev';
      }

      points[ioa] = ClientPointModel(
        commonAddress: commonAddress,
        ioa: ioa,
        typeId: typeId,
        name: '$prefix #${i + 1}',
        nameKey: key,
        value: val,
      );
    }
    onDataChanged?.call();
  }

  void applyTemplate(String templateKey) {
    if (templateKey == 'distribution') {
      nameKey = 'preset_station_10kv';
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
        prefix: 'Feeder Disconnector Status',
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
      nameKey = 'preset_station_110kv';
      // Substation Template: 32 YX + 16 YC + 8 DP + 4 YM
      batchGeneratePoints(
        typeId: AsduTypeId.mSpNa1,
        startIoa: 1,
        count: 32,
        prefix: 'Station Breaker Status',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mDpNa1,
        startIoa: 1001,
        count: 8,
        prefix: 'Bus Earth Switch Status',
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
        prefix: 'Transformer High-Voltage Energy',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'commonAddress': commonAddress,
        'name': name,
        'nameKey': nameKey,
        'points': points.values.map((p) => p.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    name = json['name'] as String? ?? name;
    nameKey = json['nameKey'] as String? ?? json['NameKey'] as String?;
    if (nameKey == null) {
      if (commonAddress == 1) {
        nameKey = 'preset_station_110kv';
      } else if (commonAddress == 2) {
        nameKey = 'preset_station_10kv';
      } else if (commonAddress == 3) {
        nameKey = 'preset_station_solar';
      } else if (commonAddress == 4) {
        nameKey = 'preset_station_bms';
      }
    }
    final list = json['points'] as List?;
    if (list != null) {
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final p = ClientPointModel.fromJson(commonAddress, item);
          points[p.ioa] = p;
        }
      }
    }
    onDataChanged?.call();
  }

  void clear() {
    points.clear();
    onDataChanged?.call();
  }
}
