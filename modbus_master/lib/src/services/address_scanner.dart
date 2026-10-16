import 'dart:async';
import '../models/register_group.dart';
import '../protocol/modbus_client.dart';

class ScanResult {
  final int idOrAddress;
  final bool isSuccess;
  final String detail;
  final int latencyMs;

  ScanResult({
    required this.idOrAddress,
    required this.isSuccess,
    required this.detail,
    required this.latencyMs,
  });
}

class AddressScannerService {
  final ModbusClient client;
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  AddressScannerService(this.client);

  void stopScan() {
    _isScanning = false;
  }

  /// Scans Slave IDs in range [fromId] .. [toId] (e.g. 1..247)
  Stream<ScanResult> scanSlaveIds({
    int fromId = 1,
    int toId = 32,
    int timeoutMs = 250,
  }) async* {
    _isScanning = true;

    for (int id = fromId; id <= toId; id++) {
      if (!_isScanning) break;

      final sw = Stopwatch()..start();
      try {
        // Try reading Holding Register 0 or 1 with a short timeout
        final words = await client.readHoldingRegisters(
          unitId: id,
          startAddress: 0,
          quantity: 1,
          customTimeoutMs: timeoutMs,
        );
        sw.stop();
        yield ScanResult(
          idOrAddress: id,
          isSuccess: true,
          detail: '从站在线! (FC03 R0=${words.first})',
          latencyMs: sw.elapsedMilliseconds,
        );
      } catch (e) {
        sw.stop();
        // If exception code is 02 (Illegal Data Address), the slave actually responded and is online!
        final errStr = e.toString();
        if (errStr.contains('IllegalDataAddress') || errStr.contains('0x02')) {
          yield ScanResult(
            idOrAddress: id,
            isSuccess: true,
            detail: '从站在线 (返回非法地址异常, 证实从机存在)',
            latencyMs: sw.elapsedMilliseconds,
          );
        } else {
          yield ScanResult(
            idOrAddress: id,
            isSuccess: false,
            detail: '无应答: $errStr',
            latencyMs: sw.elapsedMilliseconds,
          );
        }
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }

    _isScanning = false;
  }

  /// Scans register addresses for a target slave
  Stream<ScanResult> scanRegisters({
    required int unitId,
    required ModbusRegisterType type,
    int startAddress = 0,
    int count = 50,
    int timeoutMs = 300,
  }) async* {
    _isScanning = true;

    for (int addr = startAddress; addr < startAddress + count; addr++) {
      if (!_isScanning) break;

      final sw = Stopwatch()..start();
      try {
        String detail = '';
        if (type == ModbusRegisterType.coils) {
          final res = await client.readCoils(unitId: unitId, startAddress: addr, quantity: 1, customTimeoutMs: timeoutMs);
          detail = '线圈: ${res.first ? "ON (1)" : "OFF (0)"}';
        } else if (type == ModbusRegisterType.discreteInputs) {
          final res = await client.readDiscreteInputs(unitId: unitId, startAddress: addr, quantity: 1, customTimeoutMs: timeoutMs);
          detail = '离散输入: ${res.first ? "1" : "0"}';
        } else if (type == ModbusRegisterType.holdingRegisters) {
          final res = await client.readHoldingRegisters(unitId: unitId, startAddress: addr, quantity: 1, customTimeoutMs: timeoutMs);
          detail = '保持寄存器: ${res.first} (0x${res.first.toRadixString(16).padLeft(4, "0").toUpperCase()})';
        } else {
          final res = await client.readInputRegisters(unitId: unitId, startAddress: addr, quantity: 1, customTimeoutMs: timeoutMs);
          detail = '输入寄存器: ${res.first} (0x${res.first.toRadixString(16).padLeft(4, "0").toUpperCase()})';
        }
        sw.stop();
        yield ScanResult(
          idOrAddress: addr,
          isSuccess: true,
          detail: detail,
          latencyMs: sw.elapsedMilliseconds,
        );
      } catch (e) {
        sw.stop();
        yield ScanResult(
          idOrAddress: addr,
          isSuccess: false,
          detail: '读取失败: $e',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      await Future.delayed(const Duration(milliseconds: 15));
    }

    _isScanning = false;
  }
}
