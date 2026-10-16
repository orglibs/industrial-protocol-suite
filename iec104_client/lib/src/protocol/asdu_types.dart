import 'dart:typed_data';

/// Quality Descriptor (QDS / SIQ / DIQ quality flags)
class QualityDescriptor {
  final bool invalid;    // IV (Bit 7): 0 = Valid, 1 = Invalid
  final bool nonTopical; // NT (Bit 6): 0 = Topical, 1 = Not topical
  final bool substituted;// SB (Bit 5): 0 = Not substituted, 1 = Substituted
  final bool blocked;    // BL (Bit 4): 0 = Not blocked, 1 = Blocked
  final bool overflow;   // OV (Bit 0): 0 = No overflow, 1 = Overflow

  const QualityDescriptor({
    this.invalid = false,
    this.nonTopical = false,
    this.substituted = false,
    this.blocked = false,
    this.overflow = false,
  });

  static const QualityDescriptor good = QualityDescriptor();

  factory QualityDescriptor.fromByte(int byte) {
    return QualityDescriptor(
      invalid: (byte & 0x80) != 0,
      nonTopical: (byte & 0x40) != 0,
      substituted: (byte & 0x20) != 0,
      blocked: (byte & 0x10) != 0,
      overflow: (byte & 0x01) != 0,
    );
  }

  int toByte([int base = 0]) {
    int byte = base & 0x0F;
    if (invalid) byte |= 0x80;
    if (nonTopical) byte |= 0x40;
    if (substituted) byte |= 0x20;
    if (blocked) byte |= 0x10;
    if (overflow) byte |= 0x01;
    return byte;
  }

  String get summary {
    final flags = <String>[];
    if (invalid) flags.add('IV(无效)');
    if (nonTopical) flags.add('NT(非当前值)');
    if (substituted) flags.add('SB(人工置入)');
    if (blocked) flags.add('BL(闭锁)');
    if (overflow) flags.add('OV(溢出)');
    return flags.isEmpty ? 'OK(有效)' : flags.join(',');
  }

  @override
  String toString() => summary;
}

/// IEC 60870-5-104 CP56Time2a (Seven-octet binary time)
class CP56Time2a {
  final int milliseconds; // 0..59999 (bytes 0-1)
  final int minutes;      // 0..59 (byte 2, bits 0-5)
  final bool isInvalid;   // byte 2, bit 7
  final int hours;        // 0..23 (byte 3, bits 0-4)
  final bool isDaylightSaving; // byte 3, bit 7
  final int dayOfMonth;   // 1..31 (byte 4, bits 0-4)
  final int dayOfWeek;    // 1..7 (byte 4, bits 5-7, 1=Monday, 7=Sunday)
  final int month;        // 1..12 (byte 5, bits 0-3)
  final int year;         // 0..99 (byte 6, bits 0-6, represents 2000..2099)

  CP56Time2a({
    required this.milliseconds,
    required this.minutes,
    this.isInvalid = false,
    required this.hours,
    this.isDaylightSaving = false,
    required this.dayOfMonth,
    required this.dayOfWeek,
    required this.month,
    required this.year,
  });

  factory CP56Time2a.now() => CP56Time2a.fromDateTime(DateTime.now());

  factory CP56Time2a.fromDateTime(DateTime dt) {
    final ms = dt.second * 1000 + dt.millisecond;
    return CP56Time2a(
      milliseconds: ms,
      minutes: dt.minute,
      hours: dt.hour,
      dayOfMonth: dt.day,
      dayOfWeek: dt.weekday,
      month: dt.month,
      year: dt.year % 100,
    );
  }

  DateTime toDateTime() {
    final fullYear = 2000 + (year % 100);
    final sec = milliseconds ~/ 1000;
    final ms = milliseconds % 1000;
    return DateTime(fullYear, month, dayOfMonth, hours, minutes, sec, ms);
  }

  Uint8List encode() {
    final bytes = Uint8List(7);
    bytes[0] = milliseconds & 0xFF;
    bytes[1] = (milliseconds >> 8) & 0xFF;
    bytes[2] = (minutes & 0x3F) | (isInvalid ? 0x80 : 0x00);
    bytes[3] = (hours & 0x1F) | (isDaylightSaving ? 0x80 : 0x00);
    bytes[4] = (dayOfMonth & 0x1F) | ((dayOfWeek & 0x07) << 5);
    bytes[5] = month & 0x0F;
    bytes[6] = year & 0x7F;
    return bytes;
  }

  static CP56Time2a decode(Uint8List data, int offset) {
    final ms = data[offset] | (data[offset + 1] << 8);
    final minByte = data[offset + 2];
    final hrByte = data[offset + 3];
    final dayByte = data[offset + 4];
    final monByte = data[offset + 5];
    final yrByte = data[offset + 6];

    return CP56Time2a(
      milliseconds: ms,
      minutes: minByte & 0x3F,
      isInvalid: (minByte & 0x80) != 0,
      hours: hrByte & 0x1F,
      isDaylightSaving: (hrByte & 0x80) != 0,
      dayOfMonth: dayByte & 0x1F,
      dayOfWeek: (dayByte >> 5) & 0x07,
      month: monByte & 0x0F,
      year: yrByte & 0x7F,
    );
  }

  @override
  String toString() {
    final dt = toDateTime();
    final ms = milliseconds % 1000;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }
}

/// Base Information Object
abstract class InformationObject {
  int ioa; // Information Object Address (24-bit / 3 bytes)

  InformationObject({required this.ioa});

  String get displayValue;
}

/// M_SP_NA_1 (Type 1) / M_SP_TB_1 (Type 30): Single Point Information
class SinglePointObject extends InformationObject {
  bool value; // false = OFF (开/分), true = ON (合)
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  SinglePointObject({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => value ? '1 (合/ON)' : '0 (分/OFF)';
}

/// M_DP_NA_1 (Type 3) / M_DP_TB_1 (Type 31): Double Point Information
/// 00: Indeterminate, 01: OFF (分), 10: ON (合), 11: Indeterminate
class DoublePointObject extends InformationObject {
  int value; // 1 = OFF, 2 = ON, 0 = Indeterminate, 3 = Bad
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  DoublePointObject({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue {
    switch (value) {
      case 1: return '01 (分/OFF)';
      case 2: return '10 (合/ON)';
      case 0: return '00 (不确定)';
      case 3: return '11 (故障/中间态)';
      default: return '$value';
    }
  }
}

/// M_ST_NA_1 (Type 5) / M_ST_TB_1 (Type 32): Step Position Information
class StepPositionObject extends InformationObject {
  int value; // -64..63
  bool isTransient;
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  StepPositionObject({
    required super.ioa,
    required this.value,
    this.isTransient = false,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => '分接头: $value${isTransient ? " (瞬变)" : ""}';
}

/// M_BO_NA_1 (Type 7) / M_BO_TB_1 (Type 33): Bitstring of 32 bits
class Bitstring32Object extends InformationObject {
  int value; // uint32
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  Bitstring32Object({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// M_ME_NA_1 (Type 9) / M_ME_TD_1 (Type 34): Measured Value, Normalized (-1.0 .. +1.0)
class MeasuredNormalizedObject extends InformationObject {
  double value; // -1.0 .. +1.0 (internal signed 16-bit / 32768.0)
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  MeasuredNormalizedObject({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => value.toStringAsFixed(4);
}

/// M_ME_NB_1 (Type 11) / M_ME_TE_1 (Type 35): Measured Value, Scaled (-32768 .. +32767)
class MeasuredScaledObject extends InformationObject {
  int value;
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  MeasuredScaledObject({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => '$value';
}

/// M_ME_NC_1 (Type 13) / M_ME_TF_1 (Type 36): Measured Value, Short Float (IEEE 754 float32)
class MeasuredShortFloatObject extends InformationObject {
  double value;
  QualityDescriptor quality;
  CP56Time2a? timestamp;

  MeasuredShortFloatObject({
    required super.ioa,
    required this.value,
    this.quality = QualityDescriptor.good,
    this.timestamp,
  });

  @override
  String get displayValue => value.toStringAsFixed(3);
}

/// M_IT_NA_1 (Type 15) / M_IT_TB_1 (Type 37): Integrated Totals (Binary Counter Reading)
class IntegratedTotalsObject extends InformationObject {
  int counter;          // int32 counter reading
  int sequenceNumber;   // 0..31
  bool hasCarry;
  bool isAdjusted;
  bool isInvalid;
  CP56Time2a? timestamp;

  IntegratedTotalsObject({
    required super.ioa,
    required this.counter,
    this.sequenceNumber = 0,
    this.hasCarry = false,
    this.isAdjusted = false,
    this.isInvalid = false,
    this.timestamp,
  });

  @override
  String get displayValue => '$counter (Seq:$sequenceNumber)';
}

/// C_SC_NA_1 (Type 45) / C_SC_TA_1 (Type 58): Single Command (遥控单命令)
class SingleCommandObject extends InformationObject {
  final bool state;       // false = OFF, true = ON
  final bool isSelect;    // false = Execute, true = Select
  final int qualifier;    // QU (0: default, 1: short pulse, 2: long pulse, 3: persistent)
  final CP56Time2a? timestamp;

  SingleCommandObject({
    required super.ioa,
    required this.state,
    this.isSelect = false,
    this.qualifier = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '${state ? "合(ON)" : "分(OFF)"} [${isSelect ? "选择" : "执行"}]';
}

/// C_DC_NA_1 (Type 46) / C_DC_TA_1 (Type 59): Double Command (遥控双命令)
class DoubleCommandObject extends InformationObject {
  final int state;        // 1 = OFF, 2 = ON
  final bool isSelect;
  final int qualifier;
  final CP56Time2a? timestamp;

  DoubleCommandObject({
    required super.ioa,
    required this.state,
    this.isSelect = false,
    this.qualifier = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '${state == 2 ? "合(ON)" : "分(OFF)"} [${isSelect ? "选择" : "执行"}]';
}

/// C_RC_NA_1 (Type 47) / C_RC_TA_1 (Type 60): Regulating Step Command (步调节命令)
class RegulatingStepCommandObject extends InformationObject {
  final int step; // 1 = Lower, 2 = Higher
  final bool isSelect;
  final int qualifier;
  final CP56Time2a? timestamp;

  RegulatingStepCommandObject({
    required super.ioa,
    required this.step,
    this.isSelect = false,
    this.qualifier = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '${step == 2 ? "升" : "降"} [${isSelect ? "选择" : "执行"}]';
}

/// C_SE_NA_1 (Type 48) / C_SE_TA_1 (Type 61): Setpoint Command, Normalized Value
class SetpointNormalizedObject extends InformationObject {
  final double value;
  final bool isSelect;
  final int qos;
  final CP56Time2a? timestamp;

  SetpointNormalizedObject({
    required super.ioa,
    required this.value,
    this.isSelect = false,
    this.qos = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '${value.toStringAsFixed(4)} [${isSelect ? "选择" : "执行"}]';
}

/// C_SE_NB_1 (Type 49) / C_SE_TB_1 (Type 62): Setpoint Command, Scaled Value
class SetpointScaledObject extends InformationObject {
  final int value;
  final bool isSelect;
  final int qos;
  final CP56Time2a? timestamp;

  SetpointScaledObject({
    required super.ioa,
    required this.value,
    this.isSelect = false,
    this.qos = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '$value [${isSelect ? "选择" : "执行"}]';
}

/// C_SE_NC_1 (Type 50) / C_SE_TC_1 (Type 63): Setpoint Command, Short Float
class SetpointShortFloatObject extends InformationObject {
  final double value;
  final bool isSelect;
  final int qos;
  final CP56Time2a? timestamp;

  SetpointShortFloatObject({
    required super.ioa,
    required this.value,
    this.isSelect = false,
    this.qos = 0,
    this.timestamp,
  });

  @override
  String get displayValue => '${value.toStringAsFixed(3)} [${isSelect ? "选择" : "执行"}]';
}

/// C_BO_NA_1 (Type 51) / C_BO_TA_1 (Type 64): Bitstring 32 Command
class Bitstring32CommandObject extends InformationObject {
  final int value;
  final CP56Time2a? timestamp;

  Bitstring32CommandObject({
    required super.ioa,
    required this.value,
    this.timestamp,
  });

  @override
  String get displayValue => '0x${value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// C_IC_NA_1 (Type 100): Interrogation Command (总召唤命令)
class InterrogationCommandObject extends InformationObject {
  final int qoi; // 0x14 = Station interrogation

  InterrogationCommandObject({
    super.ioa = 0,
    this.qoi = 0x14,
  });

  @override
  String get displayValue => 'QOI: 0x${qoi.toRadixString(16)} (总召唤)';
}

/// C_CI_NA_1 (Type 101): Counter Interrogation Command (电能量召唤)
class CounterInterrogationCommandObject extends InformationObject {
  final int qcc; // Qualifier of counter interrogation

  CounterInterrogationCommandObject({
    super.ioa = 0,
    this.qcc = 0x05,
  });

  @override
  String get displayValue => 'QCC: 0x${qcc.toRadixString(16)} (电能量召唤)';
}

/// C_RD_NA_1 (Type 102): Read Command (读命令)
class ReadCommandObject extends InformationObject {
  ReadCommandObject({required super.ioa});

  @override
  String get displayValue => '读点命令 (IOA: $ioa)';
}

/// C_CS_NA_1 (Type 103): Clock Synchronization Command (时钟同步)
class ClockSyncCommandObject extends InformationObject {
  final CP56Time2a time;

  ClockSyncCommandObject({
    super.ioa = 0,
    required this.time,
  });

  @override
  String get displayValue => '对时: $time';
}

/// C_RP_NA_1 (Type 105): Reset Process Command (复位进程)
class ResetProcessCommandObject extends InformationObject {
  final int qrp;

  ResetProcessCommandObject({
    super.ioa = 0,
    this.qrp = 1,
  });

  @override
  String get displayValue => 'QRP: $qrp (复位进程)';
}

/// M_EI_NA_1 (Type 70): End of Initialization (初始化结束)
class EndOfInitObject extends InformationObject {
  final int coi; // Cause of initialization: 0 = Local power on, 1 = Local manual reset, 2 = Remote reset

  EndOfInitObject({
    super.ioa = 0,
    this.coi = 0,
  });

  @override
  String get displayValue => '初始化结束 (COI: $coi)';
}
