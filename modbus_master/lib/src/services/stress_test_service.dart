import 'dart:async';
import '../protocol/modbus_client.dart';

class StressTestReport {
  int totalRequests;
  int completedRequests;
  int successCount;
  int errorCount;
  int minLatencyMs;
  int maxLatencyMs;
  int totalLatencyMs;
  int currentLatencyMs;
  bool isRunning;

  StressTestReport({
    this.totalRequests = 100,
    this.completedRequests = 0,
    this.successCount = 0,
    this.errorCount = 0,
    this.minLatencyMs = 999999,
    this.maxLatencyMs = 0,
    this.totalLatencyMs = 0,
    this.currentLatencyMs = 0,
    this.isRunning = false,
  });

  double get avgLatencyMs => completedRequests > 0 ? (totalLatencyMs / completedRequests) : 0.0;
  double get successRate => completedRequests > 0 ? (successCount / completedRequests * 100.0) : 0.0;
  double get errorRate => completedRequests > 0 ? (errorCount / completedRequests * 100.0) : 0.0;
}

class StressTestService {
  final ModbusClient client;
  bool _isTesting = false;
  bool get isTesting => _isTesting;

  StressTestService(this.client);

  void stop() {
    _isTesting = false;
  }

  Stream<StressTestReport> runBenchmark({
    int unitId = 1,
    int startAddress = 0,
    int quantity = 1,
    int totalCount = 100,
    int intervalMs = 10,
  }) async* {
    _isTesting = true;

    final report = StressTestReport(
      totalRequests: totalCount,
      isRunning: true,
    );

    for (int i = 0; i < totalCount; i++) {
      if (!_isTesting) break;

      final sw = Stopwatch()..start();
      try {
        await client.readHoldingRegisters(
          unitId: unitId,
          startAddress: startAddress,
          quantity: quantity,
        );
        sw.stop();
        final ms = sw.elapsedMilliseconds;
        report.successCount++;
        report.currentLatencyMs = ms;
        report.totalLatencyMs += ms;
        if (ms < report.minLatencyMs) report.minLatencyMs = ms;
        if (ms > report.maxLatencyMs) report.maxLatencyMs = ms;
      } catch (e) {
        sw.stop();
        report.errorCount++;
        report.currentLatencyMs = sw.elapsedMilliseconds;
      } finally {
        report.completedRequests++;
        yield report;
      }

      if (intervalMs > 0) {
        await Future.delayed(Duration(milliseconds: intervalMs));
      }
    }

    report.isRunning = false;
    _isTesting = false;
    yield report;
  }
}
