# Modbus Master Emulator (MME - Flutter & Dart Native Implementation)

[English](README.md) | [简体中文](README_zh.md)

A modern, cross-platform industrial **Modbus Master Simulator** re-engineered from `ModbusMasterEmulator (MME)` using pure **Flutter & Dart**.

![Modbus Master GUI](../docs/images/screenshot_modbus_master.png)

---

## 🌟 Core Features

### 1. Robust Protocol & Transport Support
- **Modbus TCP**: Standard MBAP header processing (Transaction ID, Protocol ID, Length, Unit ID).
- **Modbus RTU over TCP / Serial RTU**: High-performance CRC-16 polynomial (`0xA001`, LSB first).
- **Modbus ASCII**: Longitudinal Redundancy Check (LRC) support.
- **Built-in Virtual Slave**:
  - Test polling and write commands immediately without any physical hardware or network connectivity.
  - Realistic electrical telemetry points (A/B/C voltages, currents, frequency, active power, transformer temperature).

### 2. Multi-Slave & Task Group Polling
- Configure independent polling cycles, timeout intervals, retry limits, and scan intervals.
- Supports single-shot scan (`Scan Once`) and continuous polling.

### 3. Binary Bit Diagnostics & Endian Switching
- 16-bit binary bitfield expansion (`0000 0000 0000 0000`) for bitwise diagnostics and quick bit toggling.
- One-click endian switching across `ABCD`, `CDAB`, `BADC`, and `DCBA`.

### 4. Diagnostic Toolbox
- Real-time CRC-16 / LRC calculation utilities.
- Integer, Float32, Float64, and Hex conversion tools.

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
