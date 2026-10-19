import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../models/connection_config.dart';
import 'modbus_frame.dart';
import 'modbus_slave_engine.dart';
import 'serial_port_adapter.dart';

class _TcpServerHandle {
  final ServerSocket server;
  final Set<Socket> activeClients = {};
  _TcpServerHandle(this.server);
}

class ModbusServerManager {
  static final ModbusServerManager instance = ModbusServerManager._();
  ModbusServerManager._();

  final Map<ConnectionConfig, _TcpServerHandle> _tcpServers = {};
  final Map<ConnectionConfig, SerialPortAdapter> _serialAdapters = {};
  final Map<ConnectionConfig, RawDatagramSocket> _udpServers = {};

  bool isConnectionRunning(ConnectionConfig config) {
    return _tcpServers.containsKey(config) ||
        _serialAdapters.containsKey(config) ||
        _udpServers.containsKey(config);
  }

  /// Starts listening for the given connection
  Future<void> startServer(ConnectionConfig config) async {
    if (isConnectionRunning(config)) return;

    try {
      switch (config.mode) {
        case ModbusTransportMode.tcp:
        case ModbusTransportMode.rtuOverTcp:
          await _startTcpServer(config);
          break;

        case ModbusTransportMode.serialRtu:
          await _startSerialServer(config);
          break;

        case ModbusTransportMode.udp:
          await _startUdpServer(config);
          break;
      }

      config.isRunning = true;
      config.statusMessage = 'Listening';
    } catch (e) {
      config.isRunning = false;
      config.statusMessage = 'Start failed: $e';
      rethrow;
    }
  }

  /// Stops listening for the given connection
  Future<void> stopServer(ConnectionConfig config) async {
    // 1. TCP Server
    final tcp = _tcpServers.remove(config);
    if (tcp != null) {
      for (final client in tcp.activeClients.toList()) {
        try {
          client.destroy();
        } catch (_) {}
      }
      tcp.activeClients.clear();
      await tcp.server.close();
    }

    // 2. Serial RTU
    final serial = _serialAdapters.remove(config);
    if (serial != null) {
      serial.dispose();
    }

    // 3. UDP
    final udp = _udpServers.remove(config);
    if (udp != null) {
      udp.close();
    }

    config.isRunning = false;
    config.clientCount = 0;
    config.statusMessage = 'Stopped';
  }

  /// Starts all connections
  Future<void> startAll(List<ConnectionConfig> configs) async {
    for (final c in configs) {
      try {
        await startServer(c);
      } catch (_) {}
    }
  }

  /// Stops all connections
  Future<void> stopAll(List<ConnectionConfig> configs) async {
    for (final c in configs) {
      try {
        await stopServer(c);
      } catch (_) {}
    }
  }

  // ================= TCP SERVER IMPLEMENTATION =================

  Future<void> _startTcpServer(ConnectionConfig config) async {
    final bindAddress = (config.ip == '0.0.0.0' || config.ip.isEmpty)
        ? InternetAddress.anyIPv4
        : InternetAddress(config.ip);

    final server = await ServerSocket.bind(bindAddress, config.port, shared: true);
    final handle = _TcpServerHandle(server);
    _tcpServers[config] = handle;

    final frameType = (config.mode == ModbusTransportMode.rtuOverTcp)
        ? ModbusFrameType.rtuOverTcp
        : ModbusFrameType.tcp;

    server.listen(
      (socket) {
        handle.activeClients.add(socket);
        config.clientCount = handle.activeClients.length;
        config.notifyUpdated();

        final rxBuffer = <int>[];

        socket.listen(
          (data) async {
            rxBuffer.addAll(data);

            while (true) {
              if (rxBuffer.isEmpty) break;
              final extracted = ModbusAdu.extractRequest(
                Uint8List.fromList(rxBuffer),
                frameType,
              );

              if (extracted == null) {
                // Wait for more bytes
                break;
              }

              // Remove consumed bytes from buffer
              rxBuffer.removeRange(0, extracted.consumed);

              config.rxCount++;
              config.notifyUpdated();

              // Process request
              final responseAdu = await ModbusSlaveEngine.processRequest(
                connection: config,
                requestAdu: extracted.adu,
              );

              if (responseAdu != null) {
                final txBytes = responseAdu.encode();
                try {
                  socket.add(txBytes);
                  await socket.flush();
                  config.txCount++;
                  config.notifyUpdated();
                } catch (_) {}
              }
            }
          },
          onError: (_) {
            handle.activeClients.remove(socket);
            config.clientCount = handle.activeClients.length;
            config.notifyUpdated();
          },
          onDone: () {
            handle.activeClients.remove(socket);
            config.clientCount = handle.activeClients.length;
            config.notifyUpdated();
          },
          cancelOnError: true,
        );
      },
      onError: (e) {
        config.statusMessage = 'Server error: $e';
        config.isRunning = false;
        config.notifyUpdated();
      },
    );
  }

  // ================= SERIAL RTU IMPLEMENTATION =================

  Future<void> _startSerialServer(ConnectionConfig config) async {
    final port = config.serialPortName ?? '/dev/ttyUSB0';
    final adapter = SerialPortAdapter(
      portName: port,
      baudRate: config.baudRate,
      dataBits: config.dataBits,
      parity: config.parity,
      stopBits: config.stopBits,
    );

    await adapter.open();
    _serialAdapters[config] = adapter;

    final rxBuffer = <int>[];

    adapter.onData.listen((data) async {
      rxBuffer.addAll(data);

      while (true) {
        if (rxBuffer.isEmpty) break;
        final extracted = ModbusAdu.extractRequest(
          Uint8List.fromList(rxBuffer),
          ModbusFrameType.rtu,
        );

        if (extracted == null) {
          // If buffer grows too long without matching a valid frame, discard oldest byte
          if (rxBuffer.length > 256) {
            rxBuffer.removeAt(0);
            continue;
          }
          break;
        }

        rxBuffer.removeRange(0, extracted.consumed);

        config.rxCount++;
        config.notifyUpdated();

        final responseAdu = await ModbusSlaveEngine.processRequest(
          connection: config,
          requestAdu: extracted.adu,
        );

        if (responseAdu != null) {
          final txBytes = responseAdu.encode();
          try {
            adapter.write(txBytes);
            config.txCount++;
            config.notifyUpdated();
          } catch (_) {}
        }
      }
    });
  }

  // ================= UDP IMPLEMENTATION =================

  Future<void> _startUdpServer(ConnectionConfig config) async {
    final bindAddress = (config.ip == '0.0.0.0' || config.ip.isEmpty)
        ? InternetAddress.anyIPv4
        : InternetAddress(config.ip);

    final socket = await RawDatagramSocket.bind(bindAddress, config.port);
    _udpServers[config] = socket;

    socket.listen((event) async {
      if (event == RawSocketEvent.read) {
        final dg = socket.receive();
        if (dg != null) {
          final extracted = ModbusAdu.extractRequest(dg.data, ModbusFrameType.tcp);
          if (extracted != null) {
            config.rxCount++;
            config.notifyUpdated();

            final responseAdu = await ModbusSlaveEngine.processRequest(
              connection: config,
              requestAdu: extracted.adu,
            );

            if (responseAdu != null) {
              final txBytes = responseAdu.encode();
              socket.send(txBytes, dg.address, dg.port);
              config.txCount++;
              config.notifyUpdated();
            }
          }
        }
      }
    });
  }
}
