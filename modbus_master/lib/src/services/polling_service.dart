import 'dart:async';
import '../models/connection_config.dart';
import '../models/register_group.dart';
import '../models/slave_model.dart';
import '../protocol/modbus_client.dart';
import '../protocol/modbus_frame.dart';
import '../i18n/app_i18n.dart';

class PollingService {
  final ModbusClient client;
  ConnectionConfig config;

  Timer? _pollingTimer;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Track last poll timestamp per group
  final Map<String, int> _lastPollMap = {};

  final StreamController<RegisterGroupModel> _groupUpdatedController = StreamController.broadcast();
  Stream<RegisterGroupModel> get onGroupUpdated => _groupUpdatedController.stream;

  PollingService({required this.client, required this.config});

  void updateConfig(ConnectionConfig newConfig) {
    config = newConfig;
    client.transportMode = config.mode;
    client.host = config.ip;
    client.port = config.port;
    client.serialPortName = config.serialPortName;
    client.baudRate = config.baudRate;
    client.dataBits = config.dataBits;
    client.parity = config.parity;
    client.stopBits = config.stopBits;
    client.isVirtualMode = config.mode == ModbusTransportMode.virtual;
    client.frameType = (config.mode == ModbusTransportMode.serialRtu || config.messageFrameFormat == 1)
        ? ModbusFrameType.rtu
        : ModbusFrameType.tcp;
    client.timeout = Duration(milliseconds: config.timeoutMs);
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _lastPollMap.clear();

    // Start cyclic timer checking groups every 100ms
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 100), _onTick);
  }

  void stop() {
    _isRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _onTick(Timer timer) async {
    if (!_isRunning) return;
    if (client.state != ModbusConnectionState.connected) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    for (final slave in config.slaves) {
      if (slave.isManualRefresh) continue;

      for (final group in slave.groups) {
        if (!group.isPollingEnabled) continue;

        final key = '${slave.slaveId}_${group.groupName}_${group.startAddress}';
        final lastPoll = _lastPollMap[key] ?? 0;
        final interval = slave.scanRate > 50 ? slave.scanRate : 1000;

        if (now - lastPoll >= interval) {
          _lastPollMap[key] = now;
          // Trigger scan asynchronously
          _scanGroup(slave, group);
        }
      }
    }
  }

  Future<void> scanGroup(SlaveModel slave, RegisterGroupModel group) async {
    return _scanGroup(slave, group);
  }

  Future<void> _scanGroup(SlaveModel slave, RegisterGroupModel group) async {
    final sw = Stopwatch()..start();
    try {
      switch (group.registerType) {
        case ModbusRegisterType.coils:
          final bits = await client.readCoils(
            unitId: slave.slaveId,
            startAddress: group.startAddress,
            quantity: group.quantity,
          );
          sw.stop();
          group.updateValues(bits.map((b) => b ? 1 : 0).toList());
          group.lastScanStatus = AppI18n.instance.t('statusOk');
          group.successCount++;
          group.lastLatencyMs = sw.elapsedMilliseconds;
          break;

        case ModbusRegisterType.discreteInputs:
          final bits = await client.readDiscreteInputs(
            unitId: slave.slaveId,
            startAddress: group.startAddress,
            quantity: group.quantity,
          );
          sw.stop();
          group.updateValues(bits.map((b) => b ? 1 : 0).toList());
          group.lastScanStatus = AppI18n.instance.t('statusOk');
          group.successCount++;
          group.lastLatencyMs = sw.elapsedMilliseconds;
          break;

        case ModbusRegisterType.holdingRegisters:
          final words = await client.readHoldingRegisters(
            unitId: slave.slaveId,
            startAddress: group.startAddress,
            quantity: group.quantity,
          );
          sw.stop();
          group.updateValues(words);
          group.lastScanStatus = AppI18n.instance.t('statusOk');
          group.successCount++;
          group.lastLatencyMs = sw.elapsedMilliseconds;
          break;

        case ModbusRegisterType.inputRegisters:
          final words = await client.readInputRegisters(
            unitId: slave.slaveId,
            startAddress: group.startAddress,
            quantity: group.quantity,
          );
          sw.stop();
          group.updateValues(words);
          group.lastScanStatus = AppI18n.instance.t('statusOk');
          group.successCount++;
          group.lastLatencyMs = sw.elapsedMilliseconds;
          break;
      }
    } catch (e) {
      sw.stop();
      group.lastScanStatus = '${AppI18n.instance.t("errorPrefix")}: $e';
      group.errorCount++;
      group.lastLatencyMs = sw.elapsedMilliseconds;
    } finally {
      group.lastScanTime = DateTime.now();
      _groupUpdatedController.add(group);
    }
  }

  void dispose() {
    stop();
    _groupUpdatedController.close();
  }
}
