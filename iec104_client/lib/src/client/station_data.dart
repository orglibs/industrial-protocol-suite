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
    required this.value,
    this.quality,
    DateTime? lastUpdated,
    this.updateCount = 1,
  }) : lastUpdated = lastUpdated ?? DateTime.now() {
    recordHistory(value, quality, this.lastUpdated);
  }

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
    if (value is bool) {
      return value ? '1 (合/ON)' : '0 (分/OFF)';
    } else if (value is double) {
      return (value as double).toStringAsFixed(2);
    } else if (value is int) {
      if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) {
        return value == 2 ? '10 (合/ON)' : (value == 1 ? '01 (分/OFF)' : '00 (不确定)');
      }
      return value.toString();
    }
    return value.toString();
  }

  String get typeCategory {
    if (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1) return '单点遥信 (YX)';
    if (typeId == AsduTypeId.mDpNa1 || typeId == AsduTypeId.mDpTb1) return '双点遥信 (YX)';
    if (typeId == AsduTypeId.mMeNc1 || typeId == AsduTypeId.mMeTf1) return '短浮点遥测 (YC)';
    if (typeId == AsduTypeId.mMeNa1 || typeId == AsduTypeId.mMeTd1) return '归一化遥测 (YC)';
    if (typeId == AsduTypeId.mMeNb1 || typeId == AsduTypeId.mMeTe1) return '标度化遥测 (YC)';
    if (typeId == AsduTypeId.mItNa1 || typeId == AsduTypeId.mItTb1) return '电能量脉冲 (YM)';
    if (typeId == AsduTypeId.mStNa1 || typeId == AsduTypeId.mStTb1) return '变压器档位 (ST)';
    if (typeId == AsduTypeId.mBoNa1 || typeId == AsduTypeId.mBoTb1) return '二进制串 (BO)';
    return '其他监视';
  }

  Map<String, dynamic> toJson() => {
        'ioa': ioa,
        'typeId': typeId.id,
        'name': name,
        'value': value,
      };

  static ClientPointModel fromJson(int ca, Map<String, dynamic> json) {
    final typeIdInt = json['typeId'] as int? ?? AsduTypeId.mMeNc1.id;
    final typeId = AsduTypeId.fromId(typeIdInt) ?? AsduTypeId.mMeNc1;
    final ioa = json['ioa'] as int? ?? 1;
    final name = json['name'] as String? ?? '点位 #$ioa';
    final val = json['value'];

    return ClientPointModel(
      commonAddress: ca,
      ioa: ioa,
      typeId: typeId,
      name: name,
      value: val ?? (typeId == AsduTypeId.mSpNa1 || typeId == AsduTypeId.mSpTb1 ? false : 0.0),
    );
  }
}

class ClientStationModel {
  int commonAddress;
  String name;
  final Map<int, ClientPointModel> points = {};
  void Function()? onDataChanged;

  ClientStationModel({
    required this.commonAddress,
    this.name = '',
    this.onDataChanged,
  }) {
    if (name.isEmpty) {
      name = '从站 (CA=$commonAddress)';
    }
  }

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

      points[ioa] = ClientPointModel(
        commonAddress: commonAddress,
        ioa: ioa,
        typeId: typeId,
        name: '$prefix #${i + 1}',
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
        prefix: '出线隔离刀闸状态',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mMeNc1,
        startIoa: 16385,
        count: 8,
        prefix: '主变馈线电压电流遥测',
      );
      batchGeneratePoints(
        typeId: AsduTypeId.mItNa1,
        startIoa: 25601,
        count: 2,
        prefix: '关口进线有功电能表',
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
        prefix: '母线接地刀闸双点遥信',
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
        prefix: '主变高压侧关口电能量',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'commonAddress': commonAddress,
        'name': name,
        'points': points.values.map((p) => p.toJson()).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    name = json['name'] as String? ?? name;
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
