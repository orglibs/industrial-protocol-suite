import '../i18n/app_i18n.dart';
import 'slave_model.dart';
import 'register_group.dart';
import 'register_model.dart';
import '../protocol/modbus_data_types.dart';

enum ModbusTransportMode {
  serialRtu(0),
  tcp(1),
  rtuOverTcp(2),
  virtual(3);

  final int code;
  const ModbusTransportMode(this.code);

  String get label {
    switch (this) {
      case ModbusTransportMode.serialRtu:
        return AppI18n.instance.t('transportRtu');
      case ModbusTransportMode.tcp:
        return AppI18n.instance.t('transportTcp');
      case ModbusTransportMode.rtuOverTcp:
        return AppI18n.instance.t('transportRtuOverTcp');
      case ModbusTransportMode.virtual:
        return AppI18n.instance.t('transportVirtual');
    }
  }

  static ModbusTransportMode fromCode(int code) {
    return ModbusTransportMode.values.firstWhere(
      (m) => m.code == code,
      orElse: () => ModbusTransportMode.tcp,
    );
  }
}

class ConnectionConfig {
  String name;
  String? nameKey;
  ModbusTransportMode mode;
  int messageFrameFormat; // 0: TCP (MBAP), 1: RTU (CRC)
  String ip;
  int port;
  String? serialPortName;
  int baudRate;
  int dataBits;
  int parity; // 0: None, 1: Odd, 2: Even
  int stopBits;
  int timeoutMs;
  List<SlaveModel> slaves;

  ConnectionConfig({
    this.name = 'Connection Alias',
    this.nameKey,
    this.mode = ModbusTransportMode.tcp,
    this.messageFrameFormat = 0,
    this.ip = '127.0.0.1',
    this.port = 502,
    this.serialPortName,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = 0,
    this.stopBits = 1,
    this.timeoutMs = 1500,
    List<SlaveModel>? slaves,
  }) : slaves = slaves ?? [];

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  int get pollingIntervalMs => slaves.isNotEmpty ? slaves.first.scanRate : 1000;

  Map<String, dynamic> toJson() => {
    'Name': name,
    if (nameKey != null) 'NameKey': nameKey,
    'ConnectionMode': mode.code,
    'MessageFrameFormat': messageFrameFormat,
    'Ip': ip,
    'Port': port,
    'SerialPortName': serialPortName,
    'BaudRate': baudRate,
    'DataBits': dataBits,
    'Parity': parity,
    'StopBits': stopBits,
    'TimeoutMs': timeoutMs,
    'SlaveModels': slaves.map((s) => s.toJson()).toList(),
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    int modeCode = 1;
    final rawMode = json['ConnectionMode'] ?? json['mode'];
    if (rawMode is int) {
      modeCode = rawMode;
    } else if (rawMode is String) {
      if (rawMode == 'virtual') {
        modeCode = 3;
      } else if (rawMode == 'serialRtu') {
        modeCode = 0;
      } else if (rawMode == 'rtuOverTcp') {
        modeCode = 2;
      } else {
        modeCode = 1;
      }
    }

    final name = json['Name'] as String? ?? json['name'] as String? ?? 'Connection Alias';
    String? nameKey = json['NameKey'] as String? ?? json['nameKey'] as String?;
    if (nameKey == null) {
      if (modeCode == 3 || name.contains('虚拟') || name.contains('Virtual')) {
        nameKey = 'transportVirtual';
      } else if (name.contains('USB0') || name.contains('串口') || name.contains('RTU')) {
        nameKey = 'preset_conn_rtu';
      } else if (name.contains('502') || name.contains('TCP')) {
        nameKey = 'preset_conn_tcp';
      }
    }

    final config = ConnectionConfig(
      name: name,
      nameKey: nameKey,
      mode: ModbusTransportMode.fromCode(modeCode),
      messageFrameFormat: json['MessageFrameFormat'] as int? ?? json['messageFrameFormat'] as int? ?? 0,
      ip: json['Ip'] as String? ?? json['ip'] as String? ?? '127.0.0.1',
      port: json['Port'] as int? ?? json['port'] as int? ?? 502,
      serialPortName: json['SerialPortName'] as String? ?? json['serialPortName'] as String?,
      baudRate: json['BaudRate'] as int? ?? json['baudRate'] as int? ?? 9600,
      dataBits: json['DataBits'] as int? ?? json['dataBits'] as int? ?? 8,
      parity: json['Parity'] as int? ?? json['parity'] as int? ?? 0,
      stopBits: json['StopBits'] as int? ?? json['stopBits'] as int? ?? 1,
      timeoutMs: json['TimeoutMs'] as int? ?? json['timeoutMs'] as int? ?? 1500,
      slaves: [],
    );

    final slavesList = json['SlaveModels'] ?? json['slaves'];
    if (slavesList != null) {
      for (var s in (slavesList as List)) {
        config.slaves.add(SlaveModel.fromJson(Map<String, dynamic>.from(s)));
      }
    }

    if (config.slaves.isEmpty) {
      config.slaves.add(ConnectionConfig.createDefaultSlave());
    }

    return config;
  }

  static SlaveModel createDefaultSlave([int id = 1, String name = 'Slave1', String? nameKey]) {
    String? defaultSlaveKey;
    if (nameKey != null) {
      defaultSlaveKey = nameKey;
    } else if (id == 1) {
      defaultSlaveKey = 'preset_slave_transformer';
    } else if (id == 2) {
      defaultSlaveKey = 'preset_slave_serial';
    } else if (id == 3) {
      defaultSlaveKey = 'preset_slave_gateway';
    }

    final slave = SlaveModel(
      name: name,
      nameKey: defaultSlaveKey,
      slaveId: id,
      registerAddressesType: 0,
      scanRate: 1000,
      isManualRefresh: false,
      byteOrder: ModbusByteOrder.abcd,
      groups: [
        RegisterGroupModel(
          groupName: 'Holding Registers - Power Telemetry',
          groupNameKey: 'preset_grp_holding_power',
          registerType: ModbusRegisterType.holdingRegisters,
          startAddress: 0,
          quantity: 12,
          registers: [
            RegisterModel(address: 0, alias: 'Phase A Voltage (V)', aliasKey: 'reg_volt_a', rawValue: 220, valueFormat: RegisterDataFormat.unsigned16, comment: 'Sine wave simulation', commentKey: 'cmt_sine_wave'),
            RegisterModel(address: 1, alias: 'Phase B Voltage (V)', aliasKey: 'reg_volt_b', rawValue: 221, valueFormat: RegisterDataFormat.unsigned16, comment: 'Sine wave simulation', commentKey: 'cmt_sine_wave'),
            RegisterModel(address: 2, alias: 'Phase C Voltage (V)', aliasKey: 'reg_volt_c', rawValue: 219, valueFormat: RegisterDataFormat.unsigned16, comment: 'Sine wave simulation', commentKey: 'cmt_sine_wave'),
            RegisterModel(address: 3, alias: 'Phase A Current (A*10)', aliasKey: 'reg_curr_a', rawValue: 52, valueFormat: RegisterDataFormat.unsigned16, comment: '5.2A -> 52'),
            RegisterModel(address: 4, alias: 'Phase B Current (A*10)', aliasKey: 'reg_curr_b', rawValue: 51, valueFormat: RegisterDataFormat.unsigned16, comment: '5.1A -> 51'),
            RegisterModel(address: 5, alias: 'Phase C Current (A*10)', aliasKey: 'reg_curr_c', rawValue: 53, valueFormat: RegisterDataFormat.unsigned16, comment: '5.3A -> 53'),
            RegisterModel(address: 6, alias: 'Active Power (W)', aliasKey: 'reg_p_active', rawValue: 3450, valueFormat: RegisterDataFormat.unsigned16, comment: 'P = 3450W'),
            RegisterModel(address: 7, alias: 'Reactive Power (Var)', aliasKey: 'reg_q_reactive', rawValue: 420, valueFormat: RegisterDataFormat.unsigned16, comment: 'Q = 420Var'),
            RegisterModel(address: 8, alias: 'Grid Frequency (Hz*100)', aliasKey: 'reg_grid_freq', rawValue: 5000, valueFormat: RegisterDataFormat.unsigned16, comment: '50.00Hz -> 5000'),
            RegisterModel(address: 9, alias: 'Power Factor (*1000)', aliasKey: 'reg_power_factor', rawValue: 985, valueFormat: RegisterDataFormat.unsigned16, comment: '0.985 -> 985'),
            RegisterModel(address: 10, alias: 'Transformer Oil Temp (°C)', aliasKey: 'reg_oil_temp', rawValue: 45, valueFormat: RegisterDataFormat.unsigned16, comment: '45°C'),
            RegisterModel(address: 11, alias: 'Device Operating Status', aliasKey: 'reg_device_status', rawValue: 1, valueFormat: RegisterDataFormat.hex16, comment: '0x0001: Normal Operation', commentKey: 'cmt_normal_op'),
          ],
        ),
        RegisterGroupModel(
          groupName: 'Coil Status - Switch Telemetry',
          groupNameKey: 'preset_grp_coils_switch',
          registerType: ModbusRegisterType.coils,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: 'Feeder #1 Closed', aliasKey: 'reg_feeder1_closed', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: 'Feeder #2 Closed', aliasKey: 'reg_feeder2_closed', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: 'Bus Tie Closed', aliasKey: 'reg_bustie_closed', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: 'Overcurrent Alarm', aliasKey: 'reg_overcurrent_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: 'Zero Sequence Ground Alarm', aliasKey: 'reg_zeroseq_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: 'Remote Interlock Blocked', aliasKey: 'reg_remote_interlock', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 6, alias: 'Exhaust Fan Running', aliasKey: 'reg_fan_running', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 7, alias: 'DC Panel Fault Alarm', aliasKey: 'reg_dc_panel_fault', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
          ],
        ),
      ],
    );
    return slave;
  }

  static ConnectionConfig createDefault() {
    return ConnectionConfig(
      name: 'Local Virtual Slave (Virtual Test)',
      nameKey: 'transportVirtual',
      mode: ModbusTransportMode.virtual,
      ip: '127.0.0.1',
      port: 502,
      slaves: [ConnectionConfig.createDefaultSlave(1, 'Substation Main Transformer (Unit 1)', 'preset_slave_transformer')],
    );
  }
}
