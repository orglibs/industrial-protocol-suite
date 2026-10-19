import 'dart:math';
import '../i18n/app_i18n.dart';
import '../protocol/modbus_data_types.dart';
import 'register_model.dart';
import 'simulation_config.dart';

enum ModbusRegisterType {
  coils(0, 1, '0x'),
  discreteInputs(1, 2, '1x'),
  holdingRegisters(2, 3, '4x'),
  inputRegisters(3, 4, '3x');

  final int code;
  final int fc;
  final String prefix;
  const ModbusRegisterType(this.code, this.fc, this.prefix);

  String get label {
    switch (this) {
      case ModbusRegisterType.coils:
        return AppI18n.instance.t('regTypeCoils');
      case ModbusRegisterType.discreteInputs:
        return AppI18n.instance.t('regTypeDiscrete');
      case ModbusRegisterType.holdingRegisters:
        return AppI18n.instance.t('regTypeHolding');
      case ModbusRegisterType.inputRegisters:
        return AppI18n.instance.t('regTypeInput');
    }
  }

  static ModbusRegisterType fromCode(int code) {
    return ModbusRegisterType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => ModbusRegisterType.holdingRegisters,
    );
  }
}

class RegisterGroupModel {
  String groupName;
  String? groupNameKey;
  ModbusRegisterType registerType;
  int startAddress;
  int quantity;
  List<RegisterModel> registers;

  RegisterGroupModel({
    required this.groupName,
    this.groupNameKey,
    this.registerType = ModbusRegisterType.holdingRegisters,
    this.startAddress = 0,
    this.quantity = 10,
    List<RegisterModel>? registers,
  }) : registers = registers ?? [] {
    syncRegisters();
  }

  String get displayGroupName => (groupNameKey != null && groupNameKey!.isNotEmpty)
      ? AppI18n.instance.t(groupNameKey!)
      : groupName;

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
    'GroupNameKey': groupNameKey,
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
    String? nameKey = json['GroupNameKey'] as String?;
    if (nameKey == null) {
      if (typeCode == 2 && (name.contains('Holding') || name.contains('保持'))) {
        nameKey = 'preset_grp_holding_power';
      } else if (typeCode == 3 && (name.contains('Input') || name.contains('输入'))) {
        nameKey = 'preset_grp_input_sensor';
      } else if (typeCode == 0 && (name.contains('Coil') || name.contains('线圈'))) {
        nameKey = 'preset_grp_coils_switch';
      } else if (typeCode == 1 && (name.contains('Discrete') || name.contains('离散'))) {
        nameKey = 'preset_grp_discrete_alarm';
      }
    }

    List<RegisterModel> regs = [];
    if (json['RegisterModels'] != null) {
      for (var r in (json['RegisterModels'] as List)) {
        regs.add(RegisterModel.fromJson(Map<String, dynamic>.from(r)));
      }
    }

    final group = RegisterGroupModel(
      groupName: name,
      groupNameKey: nameKey,
      registerType: ModbusRegisterType.fromCode(typeCode),
      startAddress: startAddr,
      quantity: qty,
      registers: regs,
    );
    group.syncRegisters();
    return group;
  }
}
