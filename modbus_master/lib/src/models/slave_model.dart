import '../protocol/modbus_data_types.dart';
import 'register_group.dart';

class SlaveModel {
  String name;
  int slaveId;
  int registerAddressesType; // 0: 0-based (0..9999), 1: 1-based (1..10000), 2: PLC standard (40001..)
  int scanRate; // Polling cycle in milliseconds (default 1000ms)
  bool isManualRefresh; // If true, do not poll automatically
  ModbusByteOrder byteOrder;
  List<RegisterGroupModel> groups;

  SlaveModel({
    required this.name,
    this.slaveId = 1,
    this.registerAddressesType = 0,
    this.scanRate = 1000,
    this.isManualRefresh = false,
    this.byteOrder = ModbusByteOrder.abcd,
    List<RegisterGroupModel>? groups,
  }) : groups = groups ?? [];

  /// Format an address according to slave's address mode
  String formatAddress(int baseAddress, ModbusRegisterType type) {
    switch (registerAddressesType) {
      case 0:
        return baseAddress.toString().padLeft(5, '0');
      case 1:
        return (baseAddress + 1).toString().padLeft(5, '0');
      case 2:
      default:
        // PLC convention: 0x => 00001+, 1x => 10001+, 3x => 30001+, 4x => 40001+
        int offset = 1;
        if (type == ModbusRegisterType.discreteInputs) offset = 10001;
        if (type == ModbusRegisterType.inputRegisters) offset = 30001;
        if (type == ModbusRegisterType.holdingRegisters) offset = 40001;
        return (offset + baseAddress).toString().padLeft(5, '0');
    }
  }

  Map<String, dynamic> toJson() => {
    'Name': name,
    'SlaveId': slaveId,
    'RegisterAddressesType': registerAddressesType,
    'ScanRate': scanRate,
    'IsManualRefresh': isManualRefresh,
    'ByteOrder': byteOrder.index,
    'RegisterGroupModels': groups.map((g) => g.toJson()).toList(),
  };

  factory SlaveModel.fromJson(Map<String, dynamic> json) {
    int byteOrderIdx = json['ByteOrder'] as int? ?? 0;
    if (byteOrderIdx < 0 || byteOrderIdx >= ModbusByteOrder.values.length) {
      byteOrderIdx = 0;
    }

    final slave = SlaveModel(
      name: json['Name'] as String? ?? 'Slave1',
      slaveId: json['SlaveId'] as int? ?? 1,
      registerAddressesType: json['RegisterAddressesType'] as int? ?? 0,
      scanRate: json['ScanRate'] as int? ?? 1000,
      isManualRefresh: json['IsManualRefresh'] as bool? ?? false,
      byteOrder: ModbusByteOrder.values[byteOrderIdx],
      groups: [],
    );

    if (json['RegisterGroupModels'] != null) {
      for (var g in (json['RegisterGroupModels'] as List)) {
        slave.groups.add(RegisterGroupModel.fromJson(Map<String, dynamic>.from(g)));
      }
    }
    return slave;
  }
}
