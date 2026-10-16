import '../protocol/modbus_data_types.dart';
import 'slave_model.dart';
import 'register_group.dart';
import 'register_model.dart';
import 'simulation_config.dart';

enum ModbusTransportMode {
  tcp(0, 'Modbus TCP Server (以太网/局域网服务端)'),
  serialRtu(1, 'Modbus RTU 串口从站 (物理串口/COM/tty)'),
  rtuOverTcp(2, 'Modbus RTU over TCP 服务端'),
  udp(3, 'Modbus UDP 服务端');

  final int code;
  final String label;
  const ModbusTransportMode(this.code, this.label);

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
    final config = ConnectionConfig(
      name: json['Name'] as String? ?? 'Connection Alias',
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

  static SlaveModel createDefaultSlave([int id = 1, String name = 'Slave1']) {
    final slave = SlaveModel(
      name: name,
      slaveId: id,
      registerAddressesType: 0,
      responseDelay: 0,
      byteOrder: ModbusByteOrder.abcd,
      groups: [
        RegisterGroupModel(
          groupName: '保持寄存器-电力模拟量 (Holding 4x)',
          registerType: ModbusRegisterType.holdingRegisters,
          startAddress: 0,
          quantity: 12,
          registers: [
            RegisterModel(
              address: 0,
              alias: 'A相电压(V)',
              rawValue: 220,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '正弦波动模拟',
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
              alias: 'B相电压(V)',
              rawValue: 221,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '正弦波动模拟',
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
              alias: 'C相电压(V)',
              rawValue: 219,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '正弦波动模拟',
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
              alias: 'A相电流(A*10)',
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
              alias: 'B相电流(A*10)',
              rawValue: 51,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '5.1A',
            ),
            RegisterModel(
              address: 5,
              alias: 'C相电流(A*10)',
              rawValue: 53,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '5.3A',
            ),
            RegisterModel(
              address: 6,
              alias: '有功功率(W)',
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
              alias: '无功功率(Var)',
              rawValue: 420,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'Q = 420Var',
            ),
            RegisterModel(
              address: 8,
              alias: '电网频率(Hz*100)',
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
              alias: '功率因数(*1000)',
              rawValue: 985,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: 'cos phi = 0.985',
            ),
            RegisterModel(
              address: 10,
              alias: '变压器油温(°C)',
              rawValue: 48,
              valueFormat: RegisterDataFormat.unsigned16,
              comment: '48°C',
            ),
            RegisterModel(
              address: 11,
              alias: '设备运行状态',
              rawValue: 1,
              valueFormat: RegisterDataFormat.hex16,
              comment: '0x0001: 正常运行',
            ),
          ],
        ),
        RegisterGroupModel(
          groupName: '输入寄存器-传感器数据 (Input 3x)',
          registerType: ModbusRegisterType.inputRegisters,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: '机房环境温度(°C*10)', rawValue: 245, valueFormat: RegisterDataFormat.unsigned16, comment: '24.5°C'),
            RegisterModel(address: 1, alias: '机房相对湿度(%*10)', rawValue: 552, valueFormat: RegisterDataFormat.unsigned16, comment: '55.2%'),
            RegisterModel(address: 2, alias: '烟雾浓度(PPM)', rawValue: 12, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 3, alias: '蓄电池组总电压(V*10)', rawValue: 2480, valueFormat: RegisterDataFormat.unsigned16, comment: '248.0V'),
            RegisterModel(address: 4, alias: '母线正对地绝缘(kΩ)', rawValue: 999, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 5, alias: '母线负对地绝缘(kΩ)', rawValue: 999, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 6, alias: '防雷器漏电流(uA)', rawValue: 15, valueFormat: RegisterDataFormat.unsigned16),
            RegisterModel(address: 7, alias: '备用测量通道', rawValue: 0, valueFormat: RegisterDataFormat.unsigned16),
          ],
        ),
        RegisterGroupModel(
          groupName: '线圈状态-开关遥信 (Coils 0x)',
          registerType: ModbusRegisterType.coils,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: '1#进线主开关合位', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: '2#进线主开关合位', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: '母联开关合位', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: '过流保护告警', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: '零序接地告警', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: '远方就地闭锁', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 6, alias: '排风机运行指示', rawValue: 1, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 7, alias: '直流屏故障告警', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
          ],
        ),
        RegisterGroupModel(
          groupName: '离散输入-保护遥信 (Discrete 1x)',
          registerType: ModbusRegisterType.discreteInputs,
          startAddress: 0,
          quantity: 6,
          registers: [
            RegisterModel(address: 0, alias: '门禁开启开关', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: '水浸探测器', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: '红外双鉴报警', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: '急停按钮动作', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: '火灾探测器动作', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: '防雷模块失效', rawValue: 0, valueFormat: RegisterDataFormat.bin16),
          ],
        ),
      ],
    );
    return slave;
  }
}
