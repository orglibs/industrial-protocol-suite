import '../i18n/app_i18n.dart';
import '../protocol/modbus_data_types.dart';

class RegisterModel {
  int address;
  String? alias;
  String? aliasKey;
  int rawValue; // 16-bit word value (0..65535) or 0/1 for coil/discrete
  RegisterDataFormat valueFormat;
  String? comment;
  String? commentKey;
  int backgroundBrush;
  int foregroundBrush;

  RegisterModel({
    required this.address,
    this.alias,
    this.aliasKey,
    this.rawValue = 0,
    this.valueFormat = RegisterDataFormat.unsigned16,
    this.comment,
    this.commentKey,
    this.backgroundBrush = 0xFFFFFFFF,
    this.foregroundBrush = 0xFF000000,
  });

  String? get displayAlias => (aliasKey != null && aliasKey!.isNotEmpty)
      ? AppI18n.instance.t(aliasKey!)
      : alias;

  String? get displayComment => (commentKey != null && commentKey!.isNotEmpty)
      ? AppI18n.instance.t(commentKey!)
      : comment;

  String getDisplayValue([ModbusByteOrder byteOrder = ModbusByteOrder.abcd, List<int>? neighborWords]) {
    switch (valueFormat) {
      case RegisterDataFormat.hex16:
      case RegisterDataFormat.bin16:
      case RegisterDataFormat.signed16:
      case RegisterDataFormat.unsigned16:
        return ModbusDataConverter.formatSingleRegister(rawValue, valueFormat);
      case RegisterDataFormat.signed32:
      case RegisterDataFormat.unsigned32:
      case RegisterDataFormat.float32:
        final w2 = (neighborWords != null && neighborWords.isNotEmpty) ? neighborWords[0] : 0;
        final words = [rawValue, w2];
        final bytes = ModbusDataConverter.registersToBytes(words);
        final val = ModbusDataConverter.parseValue(bytes, valueFormat, byteOrder);
        return val.toString();
      case RegisterDataFormat.signed64:
      case RegisterDataFormat.double64:
        final w2 = (neighborWords != null && neighborWords.isNotEmpty) ? neighborWords[0] : 0;
        final w3 = (neighborWords != null && neighborWords.length > 1) ? neighborWords[1] : 0;
        final w4 = (neighborWords != null && neighborWords.length > 2) ? neighborWords[2] : 0;
        final words = [rawValue, w2, w3, w4];
        final bytes = ModbusDataConverter.registersToBytes(words);
        final val = ModbusDataConverter.parseValue(bytes, valueFormat, byteOrder);
        return val.toString();
      case RegisterDataFormat.asciiString:
        final char1 = String.fromCharCode((rawValue >> 8) & 0xFF);
        final char2 = String.fromCharCode(rawValue & 0xFF);
        return '$char1$char2';
    }
  }

  Map<String, dynamic> toJson() => {
    'Address': address,
    'Alias': alias,
    if (aliasKey != null) 'AliasKey': aliasKey,
    'Value': rawValue,
    'ValueFormat': valueFormat.index,
    'Comment': comment,
    if (commentKey != null) 'CommentKey': commentKey,
    'BackgroundBrush': backgroundBrush,
    'ForegroundBrush': foregroundBrush,
  };

  factory RegisterModel.fromJson(Map<String, dynamic> json) {
    int formatIdx = json['ValueFormat'] as int? ?? json['valueFormat'] as int? ?? 3;
    if (formatIdx < 0 || formatIdx >= RegisterDataFormat.values.length) {
      formatIdx = 3;
    }
    final alias = json['Alias'] as String? ?? json['alias'] as String?;
    String? aliasKey = json['AliasKey'] as String? ?? json['aliasKey'] as String?;
    final comment = json['Comment'] as String? ?? json['comment'] as String?;
    String? commentKey = json['CommentKey'] as String? ?? json['commentKey'] as String?;

    if (aliasKey == null && alias != null) {
      if (alias.contains('A相电压') || alias.contains('Phase A Voltage')) aliasKey = 'reg_volt_a';
      else if (alias.contains('B相电压') || alias.contains('Phase B Voltage')) aliasKey = 'reg_volt_b';
      else if (alias.contains('C相电压') || alias.contains('Phase C Voltage')) aliasKey = 'reg_volt_c';
      else if (alias.contains('A相电流') || alias.contains('Phase A Current')) aliasKey = 'reg_curr_a';
      else if (alias.contains('B相电流') || alias.contains('Phase B Current')) aliasKey = 'reg_curr_b';
      else if (alias.contains('C相电流') || alias.contains('Phase C Current')) aliasKey = 'reg_curr_c';
      else if (alias.contains('有功功率') || alias.contains('Active Power')) aliasKey = 'reg_p_active';
      else if (alias.contains('无功功率') || alias.contains('Reactive Power')) aliasKey = 'reg_q_reactive';
      else if (alias.contains('电网频率') || alias.contains('Grid Frequency')) aliasKey = 'reg_grid_freq';
      else if (alias.contains('功率因数') || alias.contains('Power Factor')) aliasKey = 'reg_power_factor';
      else if (alias.contains('油温') || alias.contains('变压器温度') || alias.contains('Oil Temp')) aliasKey = 'reg_oil_temp';
      else if (alias.contains('设备运行状态') || alias.contains('Device Status')) aliasKey = 'reg_device_status';
      else if (alias.contains('环境温度') || alias.contains('Ambient Temp')) aliasKey = 'reg_ambient_temp';
      else if (alias.contains('相对湿度') || alias.contains('Ambient Hum')) aliasKey = 'reg_ambient_hum';
      else if (alias.contains('烟雾') || alias.contains('Smoke')) aliasKey = 'reg_smoke_ppm';
      else if (alias.contains('蓄电池') || alias.contains('Battery')) aliasKey = 'reg_battery_v';
      else if (alias.contains('正对地') || alias.contains('Pos Bus')) aliasKey = 'reg_pos_bus_ins';
      else if (alias.contains('负对地') || alias.contains('Neg Bus')) aliasKey = 'reg_neg_bus_ins';
      else if (alias.contains('防雷器漏电') || alias.contains('Surge Leakage')) aliasKey = 'reg_surge_leakage';
      else if (alias.contains('备用') || alias.contains('Spare')) aliasKey = 'reg_spare_channel';
      else if (alias.contains('1#进线') || alias.contains('Feeder #1')) aliasKey = 'reg_feeder1_closed';
      else if (alias.contains('2#进线') || alias.contains('Feeder #2')) aliasKey = 'reg_feeder2_closed';
      else if (alias.contains('母联') || alias.contains('Bus Tie')) aliasKey = 'reg_bustie_closed';
      else if (alias.contains('过流') || alias.contains('Overcurrent')) aliasKey = 'reg_overcurrent_alarm';
      else if (alias.contains('接地') || alias.contains('Ground Alarm')) aliasKey = 'reg_zeroseq_alarm';
      else if (alias.contains('闭锁') || alias.contains('Interlock')) aliasKey = 'reg_remote_interlock';
      else if (alias.contains('排风机') || alias.contains('Exhaust Fan') || alias.contains('散热风机')) aliasKey = 'reg_fan_running';
      else if (alias.contains('直流屏') || alias.contains('DC Power') || alias.contains('UPS')) aliasKey = 'reg_dc_panel_fault';
      else if (alias.contains('门禁') || alias.contains('Door Open')) aliasKey = 'reg_door_open';
      else if (alias.contains('水浸') || alias.contains('Water Leak')) aliasKey = 'reg_water_leak';
      else if (alias.contains('红外') || alias.contains('Motion Alarm')) aliasKey = 'reg_motion_alarm';
      else if (alias.contains('急停') || alias.contains('Emergency Stop')) aliasKey = 'reg_estop_action';
      else if (alias.contains('火灾') || alias.contains('Fire Alarm')) aliasKey = 'reg_fire_alarm';
      else if (alias.contains('防雷模块') || alias.contains('Surge Protection Failure')) aliasKey = 'reg_surge_fail';
    }

    if (commentKey == null && comment != null) {
      if (comment.contains('正弦') || comment.contains('Sine')) commentKey = 'cmt_sine_wave';
      else if (comment.contains('正常') || comment.contains('Normal')) commentKey = 'cmt_normal_op';
    }

    return RegisterModel(
      address: json['Address'] as int? ?? json['address'] as int? ?? 0,
      alias: alias,
      aliasKey: aliasKey,
      rawValue: (json['Value'] as num?)?.toInt() ?? (json['rawValue'] as num?)?.toInt() ?? 0,
      valueFormat: RegisterDataFormat.values[formatIdx],
      comment: comment,
      commentKey: commentKey,
      backgroundBrush: json['BackgroundBrush'] as int? ?? json['backgroundBrush'] as int? ?? 0xFFFFFFFF,
      foregroundBrush: json['ForegroundBrush'] as int? ?? json['foregroundBrush'] as int? ?? 0xFF000000,
    );
  }
}
