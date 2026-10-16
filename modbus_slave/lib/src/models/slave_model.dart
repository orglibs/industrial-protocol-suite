import '../protocol/modbus_data_types.dart';
import '../protocol/modbus_pdu.dart';
import 'register_group.dart';
import 'register_model.dart';

class SlaveModel {
  String name;
  int slaveId;
  int registerAddressesType; // 0: 0-based (0..9999), 1: 1-based (1..10000), 2: PLC standard (40001..)
  int responseDelay; // Response delay in milliseconds (MSE feature)
  ModbusByteOrder byteOrder;
  List<RegisterGroupModel> groups;

  SlaveModel({
    required this.name,
    this.slaveId = 1,
    this.registerAddressesType = 0,
    this.responseDelay = 0,
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
        int offset = 1;
        if (type == ModbusRegisterType.discreteInputs) offset = 10001;
        if (type == ModbusRegisterType.inputRegisters) offset = 30001;
        if (type == ModbusRegisterType.holdingRegisters) offset = 40001;
        return (offset + baseAddress).toString().padLeft(5, '0');
    }
  }

  /// Finds register by type and address
  RegisterModel? findRegister(ModbusRegisterType type, int address) {
    for (final group in groups) {
      if (group.registerType == type) {
        final reg = group.getRegister(address);
        if (reg != null) return reg;
      }
    }
    return null;
  }

  /// Handles FC 01: Read Coils
  List<bool> handleReadCoils(int startAddress, int quantity) {
    if (quantity < 1 || quantity > 2000) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    final result = <bool>[];
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.coils, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
      result.add(reg.rawValue != 0);
    }
    return result;
  }

  /// Handles FC 02: Read Discrete Inputs
  List<bool> handleReadDiscreteInputs(int startAddress, int quantity) {
    if (quantity < 1 || quantity > 2000) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    final result = <bool>[];
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.discreteInputs, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
      result.add(reg.rawValue != 0);
    }
    return result;
  }

  /// Handles FC 03: Read Holding Registers
  List<int> handleReadHoldingRegisters(int startAddress, int quantity) {
    if (quantity < 1 || quantity > 125) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    final result = <int>[];
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.holdingRegisters, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
      result.add(reg.rawValue & 0xFFFF);
    }
    return result;
  }

  /// Handles FC 04: Read Input Registers
  List<int> handleReadInputRegisters(int startAddress, int quantity) {
    if (quantity < 1 || quantity > 125) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    final result = <int>[];
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.inputRegisters, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
      result.add(reg.rawValue & 0xFFFF);
    }
    return result;
  }

  /// Handles FC 05: Write Single Coil
  void handleWriteSingleCoil(int address, bool value) {
    final reg = findRegister(ModbusRegisterType.coils, address);
    if (reg == null) {
      throw ModbusExceptionCode.illegalDataAddress;
    }
    reg.rawValue = value ? 1 : 0;
  }

  /// Handles FC 06: Write Single Register
  void handleWriteSingleRegister(int address, int value) {
    final reg = findRegister(ModbusRegisterType.holdingRegisters, address);
    if (reg == null) {
      throw ModbusExceptionCode.illegalDataAddress;
    }
    reg.rawValue = value & 0xFFFF;
  }

  /// Handles FC 15: Write Multiple Coils
  void handleWriteMultipleCoils(int startAddress, int quantity, List<bool> values) {
    if (quantity < 1 || quantity > 1968 || values.length < quantity) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    // Verify all addresses exist before writing
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.coils, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
    }
    // Perform writes
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.coils, startAddress + i)!;
      reg.rawValue = values[i] ? 1 : 0;
    }
  }

  /// Handles FC 16: Write Multiple Registers
  void handleWriteMultipleRegisters(int startAddress, int quantity, List<int> values) {
    if (quantity < 1 || quantity > 123 || values.length < quantity) {
      throw ModbusExceptionCode.illegalDataValue;
    }
    // Verify all addresses exist before writing
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.holdingRegisters, startAddress + i);
      if (reg == null) {
        throw ModbusExceptionCode.illegalDataAddress;
      }
    }
    // Perform writes
    for (int i = 0; i < quantity; i++) {
      final reg = findRegister(ModbusRegisterType.holdingRegisters, startAddress + i)!;
      reg.rawValue = values[i] & 0xFFFF;
    }
  }

  /// Handles FC 22: Mask Write Register
  /// Result = (CurrentContents AND AndMask) OR (OrMask AND (NOT AndMask))
  int handleMaskWriteRegister(int address, int andMask, int orMask) {
    final reg = findRegister(ModbusRegisterType.holdingRegisters, address);
    if (reg == null) {
      throw ModbusExceptionCode.illegalDataAddress;
    }
    final cur = reg.rawValue & 0xFFFF;
    final res = (cur & andMask) | (orMask & (~andMask & 0xFFFF));
    reg.rawValue = res & 0xFFFF;
    return reg.rawValue;
  }

  /// Clone this slave
  SlaveModel copyWith({
    String? name,
    int? slaveId,
    int? registerAddressesType,
    int? responseDelay,
    ModbusByteOrder? byteOrder,
  }) {
    return SlaveModel(
      name: name ?? this.name,
      slaveId: slaveId ?? this.slaveId,
      registerAddressesType: registerAddressesType ?? this.registerAddressesType,
      responseDelay: responseDelay ?? this.responseDelay,
      byteOrder: byteOrder ?? this.byteOrder,
      groups: groups.map((g) => RegisterGroupModel.fromJson(g.toJson())).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'Name': name,
    'SlaveId': slaveId,
    'RegisterAddressesType': registerAddressesType,
    'ResponseDelay': responseDelay,
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
      responseDelay: json['ResponseDelay'] as int? ?? 0,
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
