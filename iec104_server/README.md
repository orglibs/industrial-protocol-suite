# IEC 60870-5-104 Server Simulator (Flutter & Dart Native Implementation)

[English](README.md) | [简体中文](README_zh.md)

A modern, cross-platform **IEC 60870-5-104 RTU / Server Simulator** re-engineered from the commercial `IEC104ServerSimulator` using pure **Flutter & Dart**.

Supports **Flutter Desktop GUI**, **Flutter Web**, **pure Dart CLI background daemon**, and **zero-dependency Linux standalone binary** deployment.

![IEC 104 Server GUI](../docs/images/screenshot_iec104_server.png)

---

## Table of Contents
1. [Architecture & Protocol Mapping](#1-architecture--protocol-mapping)
2. [Supported IEC 104 Specifications](#2-supported-iec-104-specifications)
3. [System Architecture](#3-system-architecture)
4. [Project Structure](#4-project-structure)
5. [Prerequisites](#5-prerequisites)
6. [Build & Run Guide](#6-build--run-guide)
7. [Testing & Verification](#7-testing--verification)

---

## 1. Architecture & Protocol Mapping

Modeled after commercial simulators, the core logic is mapped into modular Dart components:

| Original C# / Avalonia Module | Flutter / Dart Implementation | Function Description |
| :--- | :--- | :--- |
| `Connection104ViewModel` / `ConnectionConfig104Model` | `lib/src/server/iec104_server.dart` & `client_session.dart` | Manages TCP socket listening, t0/t1/t2/t3 timers, and k/w sliding window acknowledgment |
| `StationViewModel` / `StationModel` | `lib/src/server/station.dart` | Manages Common Address of ASDU (COA), point indexing, and station datasets |
| `InterrogationHandler` (Type 100) | `ClientSession._handleGeneralInterrogation` | Responds to General Interrogation: ActCon (COT=7) -> Group Data (COT=20) -> ActTerm (COT=10) |
| `CounterInterrogationHandler` (Type 101) | `ClientSession._handleCounterInterrogation` | Responds to Counter Interrogation: ActCon (COT=7) -> Pulse Counters (COT=37) -> ActTerm (COT=10) |
| `ReadHandler` (Type 102) | `ClientSession._handleReadCommand` | Single-point read response with current value (COT=5) |
| `ClockSynchronizationHandler` (Type 103) | `ClientSession._handleClockSynchronization` | Clock synchronization with CP56Time2a validation and ActCon (COT=7) |
| `AsduHandler` (Types 45..64) | `ClientSession._handleControlCommand` | Telecontrol & setpoint commands: Select-Before-Operate (SBO), spontaneous updates |
| `AutoChangeInformationObject` / `EaseFunctions` | `lib/src/server/ease_functions.dart` | Mathematical waveform generator (Sine, Triangle, Square, Random Walk) |
| `CommunicatingTrafficWindow` | `lib/src/ui/tabs/traffic_tab.dart` | Millisecond-level communication traffic log and frame disassembly |
| `IEC104FrameParserWindow` | `lib/src/ui/tabs/parser_tab.dart` & `bin/frame_parser.dart` | Offline hex raw packet dissection and analysis tool |

---

## 2. Supported IEC 104 Specifications

### 2.1 APCI Frame Formats
* **I-Format (Information transfer)**: Sequence numbers $N(S)$ and $N(R)$ with $k$-frame sliding window and $w$-frame acknowledgment threshold.
* **S-Format (Supervisory functions)**: Automatic S-frame acknowledgment `68 04 01 00 <NR_low> <NR_high>` upon $w$ frames or $t_2$ timeout.
* **U-Format (Unnumbered control)**:
  * `STARTDT act` (0x07) / `con` (0x0B) —— Data transmission activation
  * `STOPDT act` (0x13) / `con` (0x23) —— Data transmission suspension
  * `TESTFR act` (0x43) / `con` (0x83) —— Link heartbeat and testing

### 2.2 Supported ASDU Types
* **Monitoring**:
  * Type 1 (`M_SP_NA_1`), Type 30 (`M_SP_TB_1`) - Single Point with/without CP56Time2a
  * Type 3 (`M_DP_NA_1`), Type 31 (`M_DP_TB_1`) - Double Point with/without CP56Time2a
  * Type 9 (`M_ME_NA_1`), Type 11 (`M_ME_NB_1`), Type 13 (`M_ME_NC_1`) - Measured Normalized/Scaled/Short Float
  * Type 34 (`M_ME_TD_1`), Type 35 (`M_ME_TE_1`), Type 36 (`M_ME_TF_1`) - Measured with CP56Time2a
  * Type 15 (`M_IT_NA_1`), Type 37 (`M_IT_TB_1`) - Integrated Totals (Pulse Counters)
* **Control**:
  * Type 45 (`C_SC_NA_1`) / Type 46 (`C_DC_NA_1`) - Single/Double Command (Select & Execute)
  * Type 48 / 49 / 50 - Setpoint Command (Normalized / Scaled / Short Float)
  * Type 100 (`C_IC_NA_1`) - General Interrogation
  * Type 101 (`C_CI_NA_1`) - Counter Interrogation
  * Type 103 (`C_CS_NA_1`) - Clock Synchronization

---

## 3. Build & Run Guide

### Desktop GUI Mode
```bash
# Launch on Linux desktop
flutter run -d linux

# Launch on Windows
flutter run -d windows
```

### Standalone CLI Daemon
```bash
# Run headless server CLI on custom port
dart run bin/server.dart --port 2404
```

### Compile Standalone Executable
```bash
dart compile exe bin/server.dart -o build/iec104_server_cli
./build/iec104_server_cli --port 2404
```

---

## 4. Testing & Verification

```bash
# Run automated feature verification suite
dart run bin/verify_features.dart

# Run widget and unit tests
flutter test
```

---

## 📄 License

This subproject is licensed under the [MIT License](../LICENSE).
