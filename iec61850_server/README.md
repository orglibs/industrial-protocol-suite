# IEC 61850 Server Simulator (MMS / GOOSE / SCL - Flutter & Dart)

[English](README.md) | [简体中文](README_zh.md)

A modern, cross-platform **IEC 61850 Server Simulator** built purely with Flutter and a native Dart protocol stack. Modeled after commercial `IEC61850ServerSimulator`, it features an industrial theme, SCL model tree, real-time value monitor, waveform simulator, and built-in ICD sample library.

![IEC 61850 Server GUI](../docs/images/screenshot_iec61850_server.png)

---

## 🌟 Architecture & Features

```
┌────────────────────────────────────────────────────────────────────────┐
│                   IEC 61850 Server Simulator App Layer                 │
│   [Model Tree]    [Live Monitor]    [Report Control]   [GOOSE Pub]     │
│   [File Service]  [Setting Groups]  [Traffic Sniffer]  [SCL Tools]     │
├────────────────────────────────────────────────────────────────────────┤
│                       Engine & Simulation Layer                        │
│   [MMS Provider]  [GOOSE Publisher] [Waveform Engine]  [SCL Parser]    │
├────────────────────────────────────────────────────────────────────────┤
│                     Protocol Core (Pure Dart Stack)                    │
│   [TPKT/COTP]     [ACSE / ASN.1]    [MMS Protocol]     [Raw Socket]    │
└────────────────────────────────────────────────────────────────────────┘
```

### 1. Pure Dart IEC 61850 Stack (Zero Native C Dependencies)
- **Layer 4-7**: RFC 1006 TPKT, ISO 8073 COTP (Class 0 CR/CC/DT), ISO 8650 ACSE (AARQ/AARE), ISO 9506 MMS (ASN.1 BER TLV codec).
- **MMS Services**:
  - `GetNameList`: Scope queries for VMD and Domain (Logical Devices) data objects and datasets.
  - `Read`: Single, multi-variable, and NamedVariableList dataset read operations.
  - `Write`: Write values, quality bits, timestamps; supports `Oper.ctlVal` and SBO control.
  - `InformationReport`: Push unconfirmed reports for enabled BRCB/URCB following buffer time and trigger options.
  - `File Services`: `FileDirectory`, `FileOpen`, `FileRead`, `FileClose`, and `FileDelete` for COMTRADE retrieval.

### 2. IEC 61850-8-1 GOOSE Engine
- EtherType `0x88B8` raw multicast frame generation.
- State number (`stNum`) changes, sequence number (`sqNum`) increments, and exponential backoff retransmission.

### 3. SCL (IEC 61850-6) XML Engine
- Fast parsing for ICD, CID, SCD, and SSD configurations.
- 9 bundled industry standard models (Protection, Measurement, Control, GOOSE, Wind 61400-25).

---

## 🚀 Build & Run Guide

```bash
# Launch desktop GUI
flutter run -d linux

# Run headless server CLI
dart run bin/server.dart --port 102 --scl assets/examples/server_example_basic_io.icd

# Run protocol verification suite
dart run bin/verify_server.dart
```

---

## 📄 License

This subproject is licensed under the [MIT License](../LICENSE).
