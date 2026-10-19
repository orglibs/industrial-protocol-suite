# IEC 60870-5-104 Client Simulator (Flutter & Dart Native Implementation)

[English](README.md) | [简体中文](README_zh.md)

A modern, cross-platform **IEC 60870-5-104 Master / Client Simulator** re-engineered from `IEC104ClientSimulator` using pure **Flutter & Dart**.

Supports **Flutter Linux Desktop GUI**, **Flutter Web**, **pure Dart interactive REPL console**, and **zero-dependency Linux standalone binary** deployment.

![IEC 104 Client GUI](../docs/images/screenshot_iec104_client.png)

---

## Table of Contents
1. [Core Features & Architecture](#1-core-features--architecture)
2. [Supported Master Procedures](#2-supported-master-procedures)
3. [Build & Run Guide](#3-build--run-guide)
4. [Testing & Verification](#4-testing--verification)

---

## 1. Core Features & Architecture

- **Multi-Server Connection Pool**: Save, configure, and switch between multiple remote RTU / Server connection profiles (IP, port, Common Address COA).
- **APCI Link Handshake & Supervision**: `STARTDT`, `STOPDT`, and `TESTFR` keepalive frames with configurable timeout timers ($t_0, t_1, t_2, t_3$) and sliding window parameters ($k, w$).
- **One-Click Master Commands**:
  - General Interrogation (`C_IC_NA_1` Type 100)
  - Clock Synchronization (`C_CS_NA_1` Type 103)
  - Counter Interrogation (`C_CI_NA_1` Type 101)
  - S-Confirm manual/auto response
- **Point Database & Monitoring**: Real-time table view of teleindication, telemetry, step positions, and integrated pulse totals.
- **Select-Before-Operate (SBO)**: Two-step telecontrol execution with timeout lock safety.
- **Traffic Sniffer & Hex Analyzer**: Real-time millisecond-level frame flow with detailed ASDU structure decoding.

---

## 2. Supported Master Procedures

| Procedure / ASDU | Command Type | Description |
| :--- | :--- | :--- |
| **STARTDT Activation** | U-Format 0x07 | Starts user data transmission on the 104 link |
| **STOPDT Suspension** | U-Format 0x13 | Halts data traffic without disconnecting the socket |
| **TESTFR Heartbeat** | U-Format 0x43 | Periodic test frame to detect silent link failures |
| **General Interrogation (GI)**| Type 100 | Interrogates station database with COT=6 / COT=20 |
| **Clock Synchronization** | Type 103 | Sends master UTC time encoded in CP56Time2a |
| **Counter Interrogation** | Type 101 | Summons pulse totalizers and energy meter readings |
| **Single / Double Control** | Type 45 / 46 | SBO Select and Execute commands with positive confirmation |

---

## 3. Build & Run Guide

### Desktop GUI Mode
```bash
# Launch on Linux desktop
flutter run -d linux

# Launch on Windows
flutter run -d windows
```

### Interactive CLI Mode
```bash
# Run interactive command line console
dart run bin/client.dart --ip 127.0.0.1 --port 2404
```

### Compile Standalone Binary
```bash
dart compile exe bin/client.dart -o build/iec104_client_cli
./build/iec104_client_cli --ip 127.0.0.1 --port 2404
```

---

## 4. Testing & Verification

```bash
# Run unit and widget tests
flutter test
```

---

## 📄 License

This subproject is licensed under the [MIT License](../LICENSE).
