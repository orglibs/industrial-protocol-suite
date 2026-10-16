import '../protocol/modbus_data_types.dart';
import 'register_model.dart';

enum ModbusRegisterType {
  coils(0, '01: 读线圈状态 (Coils 0x)', 1, '0x'),
  discreteInputs(1, '02: 读离散输入 (Discrete 1x)', 2, '1x'),
  holdingRegisters(2, '03: 读保持寄存器 (Holding 4x)', 3, '4x'),
  inputRegisters(3, '04: 读输入寄存器 (Input 3x)', 4, '3x');

  final int code;
  final String label;
  final int fc;
  final String prefix;
  const ModbusRegisterType(this.code, this.label, this.fc, this.prefix);

  static ModbusRegisterType fromCode(int code) {
    return ModbusRegisterType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ModbusRegisterType.holdingRegisters,
    );
  }
}

class RegisterGroupModel {
  String groupName;
  ModbusRegisterType registerType;
  int startAddress;
  int quantity;
  int stringValueFormat;
  List<RegisterModel> registers;
  bool isPollingEnabled;
  DateTime? lastScanTime;
  String? lastScanStatus;
  int successCount;
  int errorCount;
  int lastLatencyMs;

  RegisterGroupModel({
    required this.groupName,
    this.registerType = ModbusRegisterType.holdingRegisters,
    this.startAddress = 0,
    this.quantity = 10,
    this.stringValueFormat = 10,
    List<RegisterModel>? registers,
    this.isPollingEnabled = true,
    this.lastScanTime,
    this.lastScanStatus,
    this.successCount = 0,
    this.errorCount = 0,
    this.lastLatencyMs = 0,
  }) : registers = registers ?? [] {
    syncRegisters();
  }

  void syncRegisters() {
    if (quantity < 1) quantity = 1;
    if (quantity > 125) quantity = 125;

    final existingMap = {for (var r in registers) r.address: r};
    final newRegs = <RegisterModel>[];
    for (int i = 0; i < quantity; i++) {
      final addr = startAddress + i;
      if (existingMap.containsKey(addr)) {
        newRegs.add(existingMap[addr]!);
      } else {
        newRegs.add(RegisterModel(
          address: addr,
          valueFormat: (registerType == ModbusRegisterType.coils || registerType == ModbusRegisterType.discreteInputs)
              ? RegisterDataFormat.bin16
              : RegisterDataFormat.unsigned16,
        ));
      }
    }
    registers = newRegs;
  }

  void updateValues(List<int> newRawValues) {
    for (int i = 0; i < newRawValues.length && i < registers.length; i++) {
      registers[i].rawValue = newRawValues[i];
    }
  }

  Map<String, dynamic> toJson() => {
    'GroupName': groupName,
    'RegisterType': registerType.code,
    'StartAddress': startAddress,
    'Quantity': quantity,
    'StringValueFormat': stringValueFormat,
    'RegisterModels': registers.map((r) => r.toJson()).toList(),
    'IsPollingEnabled': isPollingEnabled,
  };

  factory RegisterGroupModel.fromJson(Map<String, dynamic> json) {
    final typeCode = json['RegisterType'] as int? ?? 2;
    final startAddr = json['StartAddress'] as int? ?? 0;
    final qty = json['Quantity'] as int? ?? 10;
    final name = json['GroupName'] as String? ?? 'Group';

    List<RegisterModel> regs = [];
    if (json['RegisterModels'] != null) {
      for (var r in (json['RegisterModels'] as List)) {
        regs.add(RegisterModel.fromJson(Map<String, dynamic>.from(r)));
      }
    }

    final group = RegisterGroupModel(
      groupName: name,
      registerType: ModbusRegisterType.fromCode(typeCode),
      startAddress: startAddr,
      quantity: qty,
      stringValueFormat: json['StringValueFormat'] as int? ?? 10,
      registers: regs,
      isPollingEnabled: json['IsPollingEnabled'] as bool? ?? true,
    );
    group.syncRegisters();
    return group;
  }
}
