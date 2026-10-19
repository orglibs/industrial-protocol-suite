import '../i18n/app_i18n.dart';
import '../protocol/modbus_data_types.dart';
import 'slave_model.dart';
import 'register_group.dart';
import 'register_model.dart';
import 'simulation_config.dart';

enum ModbusTransportMode {
  tcp(0),
  serialRtu(1),
  rtuOverTcp(2),
  udp(3);

  final int code;
  const ModbusTransportMode(this.code);

  String get label {
    switch (this) {
      case ModbusTransportMode.tcp:
        return AppI18n.instance.t('transportTcp');
      case ModbusTransportMode.serialRtu:
        return AppI18n.instance.t('transportRtu');
      case ModbusTransportMode.rtuOverTcp:
        return AppI18n.instance.t('transportRtuOverTcp');
      case ModbusTransportMode.udp:
        return AppI18n.instance.t('transportUdp');
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
  final List<void Function()> _listeners = [];
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void notifyListeners() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }
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
  List<SlaveModel> slaves;

  String get displayName => (nameKey != null && nameKey!.isNotEmpty)
      ? AppI18n.instance.t(nameKey!)
      : name;

  // Runtime status fields (not persisted)
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  set isRunning(bool val) {
    if (_isRunning != val) {
      _isRunning = val;
      notifyListeners();
    }
  }

  String? _statusMessage;
  String? get statusMessage => _statusMessage;
  set statusMessage(String? val) {
    _statusMessage = val;
    notifyListeners();
  }

  int clientCount = 0;
  int rxCount = 0;
  int txCount = 0;
  int errCount = 0;

  ConnectionConfig({
    this.name = 'Connection Alias',
    this.nameKey,
    this.mode = ModbusTransportMode.tcp,
    this.messageFrameFormat = 0,
    this.ip = '0.0.0.0',
    this.port = 502,
    this.serialPortName,
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = 0,
    this.stopBits = 1,
    List<SlaveModel>? slaves,
  }) : slaves = slaves ?? [];

  void notifyUpdated() {
    notifyListeners();
  }

  SlaveModel? findSlave(int slaveId) {
    for (final s in slaves) {
      if (s.slaveId == slaveId) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'Name': name,
    'NameKey': nameKey,
    'ConnectionMode': mode.code,
    'MessageFrameFormat': messageFrameFormat,
    'Ip': ip,
    'Port': port,
    'SerialPortName': serialPortName,
    'BaudRate': baudRate,
    'DataBits': dataBits,
    'Parity': parity,
    'StopBits': stopBits,
    'SlaveModels': slaves.map((s) => s.toJson()).toList(),
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    int modeCode = json['ConnectionMode'] as int? ?? 0;
    final name = json['Name'] as String? ?? 'Connection Alias';
    String? nameKey = json['NameKey'] as String?;
    if (nameKey == null) {
      if (name.contains('502') && name.contains('TCP')) {
        nameKey = 'preset_conn_tcp';
      } else if (name.contains('USB0')) {
        nameKey = 'preset_conn_rtu';
      } else if (name.contains('5020')) {
        nameKey = 'preset_conn_rtu_over_tcp';
      }
    }

    final config = ConnectionConfig(
      name: name,
      nameKey: nameKey,
      mode: ModbusTransportMode.fromCode(modeCode),
      messageFrameFormat: json['MessageFrameFormat'] as int? ?? 0,
      ip: json['Ip'] as String? ?? '0.0.0.0',
      port: json['Port'] as int? ?? 502,
      serialPortName: json['SerialPortName'] as String?,
      baudRate: json['BaudRate'] as int? ?? 9600,
      dataBits: json['DataBits'] as int? ?? 8,
      parity: json['Parity'] as int? ?? 0,
      stopBits: json['StopBits'] as int? ?? 1,
      slaves: [],
    );

    if (json['SlaveModels'] != null) {
      for (var s in (json['SlaveModels'] as List)) {
        config.slaves.add(SlaveModel.fromJson(Map<String, dynamic>.from(s)));
      }
    }

    if (config.slaves.isEmpty) {
      config.slaves.add(ConnectionConfig.createDefaultSlave(1));
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
      responseDelay: 0,
      byteOrder: ModbusByteOrder.abcd,
      groups: [
        RegisterGroupModel(
          groupName: 'Holding Registers - Power Telemetry (Holding 4x)',
          groupNameKey: 'preset_grp_holding_power',
          registerType: ModbusRegisterType.holdingRegisters,
          startAddress: 0,
          quantity: 12,
          registers: [
            RegisterModel(
              address: 0,
              alias: 'Phase A Voltage (V)',
              aliasKey: 'reg_volt_a',
              rawValue: 220,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'Sine wave simulation',
              commentKey: 'cmt_sine_wave',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.sine,
                min: 215,
                max: 225,
                durationMs: 3000,
              ),
            ),
            RegisterModel(
              address: 1,
              alias: 'Phase B Voltage (V)',
              aliasKey: 'reg_volt_b',
              rawValue: 221,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'Sine wave simulation',
              commentKey: 'cmt_sine_wave',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.sine,
                min: 216,
                max: 224,
                durationMs: 3000,
              ),
            ),
            RegisterModel(
              address: 2,
              alias: 'Phase C Voltage (V)',
              aliasKey: 'reg_volt_c',
              rawValue: 219,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'Sine wave simulation',
              commentKey: 'cmt_sine_wave',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.sine,
                min: 214,
                max: 223,
                durationMs: 3000,
              ),
            ),
            RegisterModel(
              address: 3,
              alias: 'Phase A Current (A*10)',
              aliasKey: 'reg_curr_a',
              rawValue: 52,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '5.2A',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.triangle,
                min: 40,
                max: 65,
                durationMs: 4000,
              ),
            ),
            RegisterModel(
              address: 4,
              alias: 'Phase B Current (A*10)',
              aliasKey: 'reg_curr_b',
              rawValue: 51,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '5.1A',
            ),
            RegisterModel(
              address: 5,
              alias: 'Phase C Current (A*10)',
              aliasKey: 'reg_curr_c',
              rawValue: 53,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '5.3A',
            ),
            RegisterModel(
              address: 6,
              alias: 'Active Power (W)',
              aliasKey: 'reg_p_active',
              rawValue: 3450,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'P = 3450W',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.increment,
                min: 3000,
                max: 3800,
                step: 10,
                durationMs: 500,
              ),
            ),
            RegisterModel(
              address: 7,
              alias: 'Reactive Power (Var)',
              aliasKey: 'reg_q_reactive',
              rawValue: 420,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'Q = 420Var',
            ),
            RegisterModel(
              address: 8,
              alias: 'Grid Frequency (Hz*100)',
              aliasKey: 'reg_grid_freq',
              rawValue: 5000,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '50.00Hz',
              simulation: SimulationConfig(
                enabled: true,
                waveType: EaseWaveType.random,
                min: 4995,
                max: 5005,
                durationMs: 1000,
              ),
            ),
            RegisterModel(
              address: 9,
              alias: 'Power Factor (*1000)',
              aliasKey: 'reg_power_factor',
              rawValue: 985,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'cos phi = 0.985',
            ),
            RegisterModel(
              address: 10,
              alias: 'Transformer Oil Temp (°C)',
              aliasKey: 'reg_oil_temp',
              rawValue: 48,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '48°C',
            ),
            RegisterModel(
              address: 11,
              alias: 'Device Status',
              aliasKey: 'reg_device_status',
              rawValue: 1,
              valueFormat: RegisterDataFormat.hex16,
              comment: '0x0001: Normal Operation',
              commentKey: 'cmt_normal_op',
            ),
          ],
        ),
        RegisterGroupModel(
          groupName: 'Input Registers - Sensor Telemetry (Input 3x)',
          groupNameKey: 'preset_grp_input_sensor',
          registerType: ModbusRegisterType.inputRegisters,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: 'Room Ambient Temp (°C*10)', aliasKey: 'reg_ambient_temp', rawValue: 245, valueFormat: RegisterDataFormat.unsigned16, comment: '24.5°C'),
            RegisterModel(address: 1, alias: 'Room Relative Humidity (%*10)', aliasKey: 'reg_ambient_hum', rawValue: 552, valueFormat: RegisterDataFormat.unsigned16, comment: '55.2%'),
            RegisterModel(address: 2, alias: 'Smoke Concentration (PPM)', aliasKey: 'reg_smoke_ppm', rawValue: 12, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 3, alias: 'Battery Bank Voltage (V*10)', aliasKey: 'reg_battery_v', rawValue: 2480, valueFormat: RegisterDataFormat.unsigned16, comment: '248.0V'),
            RegisterModel(address: 4, alias: 'Positive Bus Insulation (kΩ)', aliasKey: 'reg_pos_bus_ins', rawValue: 999, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 5, alias: 'Negative Bus Insulation (kΩ)', aliasKey: 'reg_neg_bus_ins', rawValue: 999, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 6, alias: 'Surge Arrester Leakage (uA)', aliasKey: 'reg_surge_leakage', rawValue: 15, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 7, alias: 'Spare Measurement Channel', aliasKey: 'reg_spare_channel', rawValue: 0, valueFormat: RegisterDataFormat.unsigned16),
          ],
        ),
        RegisterGroupModel(
          groupName: 'Coils - Switch Telemetry (Coils 0x)',
          groupNameKey: 'preset_grp_coils_switch',
          registerType: ModbusRegisterType.coils,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: 'Feeder #1 Main Breaker Closed', aliasKey: 'reg_feeder1_closed', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: 'Feeder #2 Main Breaker Closed', aliasKey: 'reg_feeder2_closed', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: 'Bus Tie Breaker Closed', aliasKey: 'reg_bustie_closed', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: 'Overcurrent Protection Alarm', aliasKey: 'reg_overcurrent_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: 'Zero Sequence Ground Alarm', aliasKey: 'reg_zeroseq_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: 'Remote/Local Interlock', aliasKey: 'reg_remote_interlock', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 6, alias: 'Exhaust Fan Running', aliasKey: 'reg_fan_running', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 7, alias: 'DC Power Panel Fault', aliasKey: 'reg_dc_panel_fault', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
          ],
        ),
        RegisterGroupModel(
          groupName: 'Discrete Inputs - Protection Alarms (Discrete 1x)',
          groupNameKey: 'preset_grp_discrete_alarm',
          registerType: ModbusRegisterType.discreteInputs,
          startAddress: 0,
          quantity: 6,
          registers: [
            RegisterModel(address: 0, alias: 'Access Door Open', aliasKey: 'reg_door_open', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: 'Water Leak Sensor', aliasKey: 'reg_water_leak', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: 'Infrared Motion Alarm', aliasKey: 'reg_motion_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: 'Emergency Stop Pressed', aliasKey: 'reg_estop_action', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: 'Fire Alarm Triggered', aliasKey: 'reg_fire_alarm', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: 'Surge Protection Failure', aliasKey: 'reg_surge_fail', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
          ],
        ),
      ],
    );
    return slave;
  }
}
