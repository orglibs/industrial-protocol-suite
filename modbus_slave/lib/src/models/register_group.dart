import 'dart:math';
import '../protocol/modbus_data_types.dart';
import 'register_model.dart';
import 'simulation_config.dart';

enum ModbusRegisterType {
  coils(0, '01: 线圈状态 (Coils 0x)', 1, '0x'),
  discreteInputs(1, '02: 离散输入 (Discrete 1x)', 2, '1x'),
  holdingRegisters(2, '03: 保持寄存器 (Holding 4x)', 3, '4x'),
  inputRegisters(3, '04: 输入寄存器 (Input 3x)', 4, '3x');

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
  List<RegisterModel> registers;

  RegisterGroupModel({
    required this.groupName,
    this.registerType = ModbusRegisterType.holdingRegisters,
    this.startAddress = 0,
    this.quantity = 10,
    List<RegisterModel>? registers,
  }) : registers = registers ?? [] {
    syncRegisters();
  }

  bool get isBitType =>
      registerType == ModbusRegisterType.coils || registerType == ModbusRegisterType.discreteInputs;

  void syncRegisters() {
    if (quantity < 1) quantity = 1;
    if (quantity > 2000) quantity = 2000;

    final existingMap = {for (var r in registers) r.address: r};
    final newRegs = <RegisterModel>[];

    for (int i = 0; i < quantity; i++) {
      final addr = startAddress + i;
      if (existingMap.containsKey(addr)) {
        newRegs.add(existingMap[addr]!);
      } else {
        newRegs.add(RegisterModel(
          address: addr,
          valueFormat: isBitType ? RegisterDataFormat.bin16 : RegisterDataFormat.unsigned16,
        ));
      }
    }
    registers = newRegs;
  }

  RegisterModel? getRegister(int addr) {
    for (final reg in registers) {
      if (reg.address == addr) return reg;
    }
    return null;
  }

  /// Batch fill constant value
  void batchFillConstant(int value) {
    final v = isBitType ? (value != 0 ? 1 : 0) : (value & 0xFFFF);
    for (final r in registers) {
      r.rawValue = v;
    }
  }

  /// Batch fill linear increment
  void batchFillIncrement(int start, int step) {
    int cur = start;
    for (final r in registers) {
      r.rawValue = isBitType ? ((cur % 2 != 0) ? 1 : 0) : (cur & 0xFFFF);
      cur += step;
    }
  }

  /// Batch fill random
  void batchFillRandom(int minVal, int maxVal) {
    final rnd = Random();
    final span = (maxVal - minVal).abs() + 1;
    for (final r in registers) {
      final v = minVal + rnd.nextInt(span);
      r.rawValue = isBitType ? ((v % 2 != 0) ? 1 : 0) : (v & 0xFFFF);
    }
  }

  /// Batch configure waveform simulation for all registers in this group
  void batchConfigureSimulation(SimulationConfig config) {
    for (final r in registers) {
      r.simulation = config.copyWith();
    }
  }

  /// Reset all register values in this group to 0
  void resetAll() {
    for (final r in registers) {
      r.rawValue = 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'GroupName': groupName,
    'RegisterType': registerType.code,
    'StartAddress': startAddress,
    'Quantity': quantity,
    'RegisterModels': registers.map((r) => r.toJson()).toList(),
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
      registers: regs,
    );
    group.syncRegisters();
    return group;
  }
}
