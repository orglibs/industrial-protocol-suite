import 'slave_model.dart';
import 'register_group.dart';
import 'register_model.dart';
import '../protocol/modbus_data_types.dart';

enum ModbusTransportMode {
  serialRtu(0, 'Modbus RTU (物理串口/COM)'),
  tcp(1, 'Modbus TCP (以太网)'),
  rtuOverTcp(2, 'Modbus RTU over TCP'),
  virtual(3, '虚拟从站 (无需外部设备直接测试)');

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
  int timeoutMs;
  List<SlaveModel> slaves;

  ConnectionConfig({
    this.name = 'Connection Alias',
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

  int get pollingIntervalMs => slaves.isNotEmpty ? slaves.first.scanRate : 1000;

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
    'TimeoutMs': timeoutMs,
    'SlaveModels': slaves.map((s) => s.toJson()).toList(),
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    int modeCode = json['ConnectionMode'] as int? ?? 1;
    final config = ConnectionConfig(
      name: json['Name'] as String? ?? 'Connection Alias',
      mode: ModbusTransportMode.fromCode(modeCode),
      messageFrameFormat: json['MessageFrameFormat'] as int? ?? 0,
      ip: json['Ip'] as String? ?? '127.0.0.1',
      port: json['Port'] as int? ?? 502,
      serialPortName: json['SerialPortName'] as String?,
      baudRate: json['BaudRate'] as int? ?? 9600,
      dataBits: json['DataBits'] as int? ?? 8,
      parity: json['Parity'] as int? ?? 0,
      stopBits: json['StopBits'] as int? ?? 1,
      timeoutMs: json['TimeoutMs'] as int? ?? 1500,
      slaves: [],
    );

    if (json['SlaveModels'] != null) {
      for (var s in (json['SlaveModels'] as List)) {
        config.slaves.add(SlaveModel.fromJson(Map<String, dynamic>.from(s)));
      }
    }

    if (config.slaves.isEmpty) {
      config.slaves.add(ConnectionConfig.createDefaultSlave());
    }

    return config;
  }

  static SlaveModel createDefaultSlave() {
    final slave = SlaveModel(
      name: 'Slave1',
      slaveId: 1,
      registerAddressesType: 0,
      scanRate: 1000,
      isManualRefresh: false,
      byteOrder: ModbusByteOrder.abcd,
      groups: [
        RegisterGroupModel(
          groupName: '保持寄存器-电力模拟量',
          registerType: ModbusRegisterType.holdingRegisters,
          startAddress: 0,
          quantity: 12,
          registers: [
            RegisterModel(address: 0, alias: 'A相电压(V)', valueFormat: RegisterDataFormat.unsigned16, comment: '220V 标称'),
            RegisterModel(address: 1, alias: 'B相电压(V)', valueFormat: RegisterDataFormat.unsigned16, comment: '220V 标称'),
            RegisterModel(address: 2, alias: 'C相电压(V)', valueFormat: RegisterDataFormat.unsigned16, comment: '220V 标称'),
            RegisterModel(address: 3, alias: 'A相电流(A*10)', valueFormat: RegisterDataFormat.unsigned16, comment: '5.2A -> 52'),
            RegisterModel(address: 4, alias: 'B相电流(A*10)', valueFormat: RegisterDataFormat.unsigned16, comment: '5.1A -> 51'),
            RegisterModel(address: 5, alias: 'C相电流(A*10)', valueFormat: RegisterDataFormat.unsigned16, comment: '5.3A -> 53'),
            RegisterModel(address: 6, alias: '有功功率(W)', valueFormat: RegisterDataFormat.unsigned16, comment: 'P = 3450W'),
            RegisterModel(address: 7, alias: '无功功率(Var)', valueFormat: RegisterDataFormat.unsigned16, comment: 'Q = 420Var'),
            RegisterModel(address: 8, alias: '电网频率(Hz*100)', valueFormat: RegisterDataFormat.unsigned16, comment: '50.00Hz -> 5000'),
            RegisterModel(address: 9, alias: '功率因数(*1000)', valueFormat: RegisterDataFormat.unsigned16, comment: '0.985 -> 985'),
            RegisterModel(address: 10, alias: '变压器温度(°C)', valueFormat: RegisterDataFormat.unsigned16, comment: '45°C'),
            RegisterModel(address: 11, alias: '设备运行状态', valueFormat: RegisterDataFormat.hex16, comment: '0x0001: 正常'),
          ],
        ),
        RegisterGroupModel(
          groupName: '线圈状态-开关遥信',
          registerType: ModbusRegisterType.coils,
          startAddress: 0,
          quantity: 8,
          registers: [
            RegisterModel(address: 0, alias: '1#进线主开关合位', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 1, alias: '2#进线主开关合位', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 2, alias: '母联开关合位', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 3, alias: '过流保护告警', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 4, alias: '接地告警', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 5, alias: '遥控允许闭锁', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 6, alias: '散热风机启动', valueFormat: RegisterDataFormat.bin16),
            RegisterModel(address: 7, alias: 'UPS故障告警', valueFormat: RegisterDataFormat.bin16),
          ],
        ),
      ],
    );
    return slave;
  }
}
