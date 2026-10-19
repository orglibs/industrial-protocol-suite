import '../i18n/app_i18n.dart';
import '../protocol/modbus_data_types.dart';
import 'register_model.dart';

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
    this.groupNameKey,
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

  String get displayGroupName => (groupNameKey != null && groupNameKey!.isNotEmpty)
      ? AppI18n.instance.t(groupNameKey!)
      : groupName;

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
    if (groupNameKey != null) 'GroupNameKey': groupNameKey,
    'RegisterType': registerType.code,
    'StartAddress': startAddress,
    'Quantity': quantity,
    'StringValueFormat': stringValueFormat,
    'RegisterModels': registers.map((r) => r.toJson()).toList(),
    'IsPollingEnabled': isPollingEnabled,
  };

  factory RegisterGroupModel.fromJson(Map<String, dynamic> json) {
    int typeCode = 2;
    final rawType = json['RegisterType'] ?? json['type'];
    if (rawType is int) {
      typeCode = rawType;
    } else if (rawType is String) {
      if (rawType == 'coils') {
        typeCode = 0;
      } else if (rawType == 'discreteInputs') {
        typeCode = 1;
      } else if (rawType == 'holdingRegisters') {
        typeCode = 2;
      } else if (rawType == 'inputRegisters') {
        typeCode = 3;
      }
    }

    final startAddr = json['StartAddress'] as int? ?? json['startAddress'] as int? ?? 0;
    final qty = json['Quantity'] as int? ?? json['quantity'] as int? ?? 10;
    final name = json['GroupName'] as String? ?? json['groupName'] as String? ?? 'Group';
    String? groupNameKey = json['GroupNameKey'] as String? ?? json['groupNameKey'] as String?;

    if (groupNameKey == null) {
      if (name.contains('保持') || name.contains('Holding') || name.contains('电力模拟量') || name.contains('三相电力') || name.contains('遥测')) {
        groupNameKey = 'preset_grp_holding_power';
      } else if (name.contains('输入') || name.contains('Input') || name.contains('传感器')) {
        groupNameKey = 'preset_grp_input_sensor';
      } else if (name.contains('线圈') || name.contains('Coil') || name.contains('开关遥信')) {
        groupNameKey = 'preset_grp_coils_switch';
      } else if (name.contains('离散') || name.contains('Discrete') || name.contains('保护遥信')) {
        groupNameKey = 'preset_grp_discrete_alarm';
      }
    }

    List<RegisterModel> regs = [];
    final regsList = json['RegisterModels'] ?? json['registers'];
    if (regsList != null) {
      for (var r in (regsList as List)) {
        regs.add(RegisterModel.fromJson(Map<String, dynamic>.from(r)));
      }
    }

    final group = RegisterGroupModel(
      groupName: name,
      groupNameKey: groupNameKey,
      registerType: ModbusRegisterType.fromCode(typeCode),
      startAddress: startAddr,
      quantity: qty,
      stringValueFormat: json['StringValueFormat'] as int? ?? json['stringValueFormat'] as int? ?? 10,
      registers: regs,
      isPollingEnabled: json['IsPollingEnabled'] as bool? ?? json['isPollingEnabled'] as bool? ?? true,
    );
    group.syncRegisters();
    return group;
  }
}
