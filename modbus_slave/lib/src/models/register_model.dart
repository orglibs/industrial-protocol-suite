import '../protocol/modbus_data_types.dart';
import 'simulation_config.dart';

class RegisterModel {
  int address;
  String? alias;
  int rawValue; // 16-bit word value (0..65535) or 0/1 for coil/discrete
  RegisterDataFormat valueFormat;
  String? comment;
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
    this.rawValue = 0,
    this.valueFormat = RegisterDataFormat.unsigned16,
    this.comment,
    this.backgroundBrush = 0xFFFFFFFF,
    this.foregroundBrush = 0xFF000000,
    this.compositeType = 0,
    this.compositeGroup = 0,
    SimulationConfig? simulation,
  }) : simulation = simulation ?? SimulationConfig();

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
    'Value': rawValue,
    'ValueFormat': valueFormat.index,
    'Comment': comment,
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
    return RegisterModel(
      address: json['Address'] as int? ?? 0,
      alias: json['Alias'] as String?,
      rawValue: (json['Value'] as num?)?.toInt() ?? 0,
      valueFormat: RegisterDataFormat.values[formatIdx],
      comment: json['Comment'] as String?,
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
