import '../i18n/app_i18n.dart';
import '../protocol/modbus_data_types.dart';
import 'simulation_config.dart';

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

  // Composite multi-register grouping (MSE feature)
  // 0: Single (16-bit)
  // 1: TwoForOne (32-bit: Float32 / Int32 / UInt32)
  // 2: FourForOne (64-bit: Double64 / Int64)
  int compositeType;
  int compositeGroup;

  // Waveform / Easing Simulation
  SimulationConfig simulation;

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
    this.compositeType = 0,
    this.compositeGroup = 0,
    SimulationConfig? simulation,
  }) : simulation = simulation ?? SimulationConfig();

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

  /// Sets register value from user input text
  /// Returns extra words if this is a composite multi-word format
  List<int>? parseAndSetDisplayValue(String text, [ModbusByteOrder byteOrder = ModbusByteOrder.abcd]) {
    final words = ModbusDataConverter.parseInputTextToWords(text, valueFormat, byteOrder);
    if (words != null && words.isNotEmpty) {
      rawValue = words[0];
      return words;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'Address': address,
    'Alias': alias,
    'AliasKey': aliasKey,
    'Value': rawValue,
    'ValueFormat': valueFormat.index,
    'Comment': comment,
    'CommentKey': commentKey,
    'BackgroundBrush': backgroundBrush,
    'ForegroundBrush': foregroundBrush,
    'CompositeType': compositeType,
    'CompositeGroup': compositeGroup,
    'Simulation': simulation.toJson(),
  };

  factory RegisterModel.fromJson(Map<String, dynamic> json) {
    int formatIdx = json['ValueFormat'] as int? ?? 3;
    if (formatIdx < 0 || formatIdx >= RegisterDataFormat.values.length) {
      formatIdx = 3;
    }
    final alias = json['Alias'] as String?;
    String? aliasKey = json['AliasKey'] as String?;
    final comment = json['Comment'] as String?;
    String? commentKey = json['CommentKey'] as String?;

    if (aliasKey == null && alias != null) {
      if (alias.contains('Phase A Volt') || alias.contains('A相电压')) {
        aliasKey = 'reg_volt_a';
      } else if (alias.contains('Phase B Volt') || alias.contains('B相电压')) {
        aliasKey = 'reg_volt_b';
      } else if (alias.contains('Phase C Volt') || alias.contains('C相电压')) {
        aliasKey = 'reg_volt_c';
      } else if (alias.contains('Phase A Curr') || alias.contains('A相电流')) {
        aliasKey = 'reg_curr_a';
      } else if (alias.contains('Phase B Curr') || alias.contains('B相电流')) {
        aliasKey = 'reg_curr_b';
      } else if (alias.contains('Phase C Curr') || alias.contains('C相电流')) {
        aliasKey = 'reg_curr_c';
      } else if (alias.contains('Active Power') || alias.contains('有功功率')) {
        aliasKey = 'reg_p_active';
      } else if (alias.contains('Reactive Power') || alias.contains('无功功率')) {
        aliasKey = 'reg_q_reactive';
      } else if (alias.contains('Frequency') || alias.contains('频率')) {
        aliasKey = 'reg_grid_freq';
      } else if (alias.contains('Power Factor') || alias.contains('功率因数')) {
        aliasKey = 'reg_power_factor';
      } else if (alias.contains('Oil Temp') || alias.contains('油温')) {
        aliasKey = 'reg_oil_temp';
      } else if (alias.contains('Device Status') || alias.contains('设备状态')) {
        aliasKey = 'reg_device_status';
      } else if (alias.contains('Ambient Temp') || alias.contains('室温')) {
        aliasKey = 'reg_ambient_temp';
      } else if (alias.contains('Humidity') || alias.contains('湿度')) {
        aliasKey = 'reg_ambient_hum';
      } else if (alias.contains('Smoke') || alias.contains('烟雾')) {
        aliasKey = 'reg_smoke_ppm';
      } else if (alias.contains('Battery') || alias.contains('蓄电池')) {
        aliasKey = 'reg_battery_v';
      } else if (alias.contains('Positive Bus') || alias.contains('正母线')) {
        aliasKey = 'reg_pos_bus_ins';
      } else if (alias.contains('Negative Bus') || alias.contains('负母线')) {
        aliasKey = 'reg_neg_bus_ins';
      } else if (alias.contains('Surge Arrester') || alias.contains('避雷器泄漏')) {
        aliasKey = 'reg_surge_leakage';
      } else if (alias.contains('Spare') || alias.contains('备用')) {
        aliasKey = 'reg_spare_channel';
      } else if (alias.contains('Feeder #1') || alias.contains('1号出线')) {
        aliasKey = 'reg_feeder1_closed';
      } else if (alias.contains('Feeder #2') || alias.contains('2号出线')) {
        aliasKey = 'reg_feeder2_closed';
      } else if (alias.contains('Bus Tie') || alias.contains('母联')) {
        aliasKey = 'reg_bustie_closed';
      } else if (alias.contains('Overcurrent') || alias.contains('过流')) {
        aliasKey = 'reg_overcurrent_alarm';
      } else if (alias.contains('Zero Sequence') || alias.contains('零序')) {
        aliasKey = 'reg_zeroseq_alarm';
      } else if (alias.contains('Interlock') || alias.contains('远方/就地')) {
        aliasKey = 'reg_remote_interlock';
      } else if (alias.contains('Fan') || alias.contains('风机')) {
        aliasKey = 'reg_fan_running';
      } else if (alias.contains('DC Power') || alias.contains('直流屏')) {
        aliasKey = 'reg_dc_panel_fault';
      } else if (alias.contains('Door') || alias.contains('防盗门')) {
        aliasKey = 'reg_door_open';
      } else if (alias.contains('Leak') || alias.contains('水浸')) {
        aliasKey = 'reg_water_leak';
      } else if (alias.contains('Infrared') || alias.contains('红外')) {
        aliasKey = 'reg_motion_alarm';
      } else if (alias.contains('Emergency Stop') || alias.contains('急停')) {
        aliasKey = 'reg_estop_action';
      } else if (alias.contains('Fire') || alias.contains('火警')) {
        aliasKey = 'reg_fire_alarm';
      } else if (alias.contains('Surge Protection Failure') || alias.contains('防雷器故障')) {
        aliasKey = 'reg_surge_fail';
      }
    }

    if (commentKey == null && comment != null) {
      if (comment.contains('Sine') || comment.contains('正弦')) {
        commentKey = 'cmt_sine_wave';
      } else if (comment.contains('Normal') || comment.contains('正常')) {
        commentKey = 'cmt_normal_op';
      }
    }

    return RegisterModel(
      address: json['Address'] as int? ?? 0,
      alias: alias,
      aliasKey: aliasKey,
      rawValue: (json['Value'] as num?)?.toInt() ?? 0,
      valueFormat: RegisterDataFormat.values[formatIdx],
      comment: comment,
      commentKey: commentKey,
      backgroundBrush: json['BackgroundBrush'] as int? ?? 0xFFFFFFFF,
      foregroundBrush: json['ForegroundBrush'] as int? ?? 0xFF000000,
      compositeType: json['CompositeType'] as int? ?? 0,
      compositeGroup: json['CompositeGroup'] as int? ?? 0,
      simulation: json['Simulation'] != null
          ? SimulationConfig.fromJson(Map<String, dynamic>.from(json['Simulation']))
          : SimulationConfig(),
    );
  }
}
