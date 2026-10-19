# Modbus Slave Emulator (MSE - Flutter & Dart Native Implementation)

[English](README.md) | [简体中文](README_zh.md)

A modern, cross-platform industrial **Modbus Slave Simulator** re-engineered from `ModbusSlaveEmulator (MSE)` using pure **Flutter & Dart**.

![Modbus Slave GUI](../docs/images/screenshot_modbus_slave.png)

---

## 🌟 Core Features

### 1. Connection-Scoped Multi-Slave Architecture (`Connection -> Slaves -> Groups`)
- **Strict connection scoping**: Slaves belong to specific connections rather than a global pool. Each connection (TCP or Serial) maintains independent slave ID addresses and register maps.
- **Transports**:
  - **Modbus TCP Server**: Binds to `0.0.0.0` or specific interfaces; default port `502` / `5020`; supports concurrent multi-client connections.
  - **Modbus RTU Serial**: Pure POSIX `libc.so.6` FFI implementation with zero external C library dependencies; supports physical and virtual serial ports (`/dev/ttyUSB*`, `/dev/ttyS*`, `/dev/pts/*`).
  - **Modbus RTU over TCP**: Serial RTU frames (with CRC-16) carried over TCP stream.
  - **Modbus UDP**: Lightweight connectionless Modbus protocol.

### 2. Full Function Code Support (FC 01 - FC 23)
- FC 01: Read Coils
- FC 02: Read Discrete Inputs
- FC 03: Read Holding Registers
- FC 04: Read Input Registers
- FC 05: Write Single Coil
- FC 06: Write Single Register
- FC 08: Diagnostics
- FC 15: Write Multiple Coils
- FC 16: Write Multiple Registers
- FC 17: Report Slave ID
- FC 22: Mask Write Register
- FC 23: Read/Write Multiple Registers

### 3. Dynamic Waveform Generator (EaseFunction)
- Mathematically generate realistic sensor data: Sine Wave, Triangle Wave, Square Wave, Linear Ramp, Random Walk, and Quintic Ease.
- Live Canvas waveform preview directly inside the GUI.

### 4. Data Representation & Endianness
- Supports 4 industrial word/byte combinations:
  - `ABCD` (Big Endian)
  - `CDAB` (Little Endian Word Swap)
  - `BADC` (Byte Swap)
  - `DCBA` (Little Endian)

---

## 🚀 Build & Run Guide

```bash
# Launch desktop GUI
flutter run -d linux

# Run unit tests
flutter test
```

---

## 📄 License

This subproject is licensed under the [MIT License](../LICENSE).
