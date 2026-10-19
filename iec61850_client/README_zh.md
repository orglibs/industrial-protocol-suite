[English](README.md) | [简体中文](README_zh.md)

# IEC 61850 MMS & GOOSE Client Simulator (工业级电力规约客户端模拟器)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS-blue)](https://flutter.dev/desktop)
[![Protocol](https://img.shields.io/badge/Protocol-IEC%2061850--8--1%20MMS%20%2F%20GOOSE-green)](https://en.wikipedia.org/wiki/IEC_61850)
[![Tests](https://img.shields.io/badge/Tests-Passing%20(100%25)-brightgreen)](test/widget_test.dart)

参考原版 `IEC61850ClientSimulator` 开发的现代化跨平台电力自动化调试客户端，基于 **Flutter / Dart** 纯自研规约协议栈实现，完美适配工业级桌面端操作需求。设计风格与 `modbus_slave` 及 `iec61850_server` 统一，提供深色/浅色高对比度工业质感 UI。

![IEC 61850 Client GUI](../docs/images/screenshot_iec61850_client.png)

---

## 🌟 核心特性全览

### 1. 全协议栈纯 Dart 实现（零外部 C 库依赖）
- **传输与会话层**：
  - **RFC 1006 TPKT** 封包与解包（Version 3，Reserved 0）。
  - **ISO 8073 COTP** 面向连接传输协议（CR / CC 连接协商、DT 数据传输，支持可配置 TSAP）。
  - **ISO 8650-1 ACSE** 关联控制服务元素（AARQ 关联请求，AARE 关联响应，支持 AP-Title / AE-Qualifier 校验）。
  - **ISO 8825 ASN.1 BER TLV** 高性能编解码器，支持不定长/定长、Primitive / Constructed 全类型解析。
- **MMS (ISO 9506) 客户端服务**：
  - `Initiate` 握手与服务参数协商（MMS 版本、最大 PDU 长度、服务支持位图）。
  - `GetNameList` 域名与变量发现（支持 VMD、Domain-specific、Association-specific 作用域查询）。
  - `Read` 变量读取（支持单点读取、多点批量读取、NamedVariableList 数据集读取）。
  - `Write` 变量写入（支持整型、浮点、布尔、位串、OctetString、UTC 时标写入及品质设定）。
  - `Select-Before-Operate (SBO)` 遥控双步控制（带倒计时锁定与取消）及 `Direct Control` 直接控制。
  - `InformationReport` 报告被动接收与解析（支持 BRCB / URCB，自发/突发变位推送）。
  - `FileDirectory` / `FileOpen` / `FileRead` / `FileClose` 远程文件服务（支持故障录波 COMTRADE 下载）。
  - `Setting Group (SGCB)` 定值区切换与监视。
- **IEC 61850-8-1 GOOSE 监听与订阅**：
  - 原生支持以太网 EtherType `0x88B8` GOOSE 帧订阅与解析。
  - 内置 ASN.1 GOOSE 报文解码（AppID、gocbRef、datSet、goID、t、stNum、sqNum、test、confRev、ndsCom、numDatSetEntries、AllData 数据结构树）。
  - 支持虚拟 GOOSE 数据帧注入测试与十六进制分析。

### 2. 现代化工业 UI 架构（与 Modbus / Server 保持风格一致）
- **导航式分屏结构**：采用 `NavigationRail` 与响应式 Tab，包含：
  - 🌲 **模型浏览器 (Model Explorer)**：树形展示 IED -> Logical Device -> Logical Node -> Data Object -> Data Attribute，支持单点详情查询、实时刷新、值修改及 SBO 遥控控制面板。
  - 📊 **数据监视表 (Data Monitor)**：测点批量监控表格，支持自定刷新周期轮询、品质码解析 (Invalid / Overflow / Test)、高亮数值变动。
  - 📑 **报告控制块 (Reports)**：BRCB/URCB 控制块列表，可在线启用/停用 (`RptEna`)、总召唤 (`GI`)、触发选项配置，并提供动态未确认报告接收流 (`InformationReport`) 列表。
  - 🦢 **GOOSE 报文监视 (GOOSE Monitor)**：抓取局域网内变电站 GOOSE 广播报文，展示状态号/顺序号、报文详情与 Raw Hex Dump。
  - 📁 **定值与文件服务 (Files & Settings)**：浏览并下载变电站远端 COMTRADE 录波文件 (`.cfg`, `.dat`)，切换定值区 (`ActSG`)。
  - 🌐 **网络报文嗅探 (Traffic Sniffer)**：Wireshark 级别报文记录器，展示时间戳、方向 (TX/RX)、协议分层 (TPKT/COTP/ACSE/MMS)、服务名称及 Hex + ASCII 双栏对照。
  - 🛠️ **SCL 离线工具与词典 (SCL Tools & Dictionaries)**：内置 9 套标准 IEC 61850 示例模型 (ICD/CID)，提供中英文逻辑节点 (LN)、数据对象 (DO)、公共数据类 (CDC) 双语速查词典。
- **多连接管理**：
  - 支持同时配置并管理多个远端变电站/服务端连接。
  - 配置持久化于本地存储 (`~/.local/share/iec61850_client/workspace.json`)。
  - 顶部一键连接/断开、在线模型动态发现 (`GetNameList`)、离线 SCL 绑定、统计指标实时刷新。

---

## 🏗️ 目录结构

```
iec61850_client/
├── assets/
│   ├── examples/              # 标准变电站 SCL/ICD 范例 (basic_io, cswi, xcbr, mmxu, etc.)
│   └── json/                  # 61850 中英文词典元数据 (ln_dict, do_dict, da_dict, cdc_dict)
├── bin/
│   ├── client.dart            # 独立 CLI 命令行客户端引擎
│   └── verify_client.dart     # 自动化全链路自测脚本（与 iec61850_server 联合回环验证）
├── lib/
│   ├── main.dart              # Flutter 桌面端主入口，工业暗黑/明亮主题配置
│   └── src/
│       ├── models/            # 规约与业务模型 (SCL模型, 测点模型, 连接配置, 词典服务)
│       ├── protocol/          # 纯 Dart 规约实现 (TPKT, COTP, ASN.1 BER, ACSE, MMS, GOOSE)
│       ├── services/          # 嗅探器日志 (TrafficLogger)
│       └── ui/                # UI 界面与 7 个功能 Tab 视图
├── test/
│   ├── iec61850_client_test.dart  # 单元测试集合
│   └── widget_test.dart           # UI 烟雾与组件测试
└── README.md
```

---

## 🚀 快速启动

### 1. 运行图形界面客户端 (Flutter Desktop)

```bash
# 进入工程目录
cd iec61850_client

# 获取依赖
flutter pub get

# 运行桌面端
flutter run -d linux
```

### 2. 运行独立 CLI 命令行客户端

无需启动图形界面，可直接在无头服务器上运行客户端：

```bash
# 查看命令行参数
dart run bin/client.dart --help

# 连接服务端并执行在线模型发现
dart run bin/client.dart --ip 127.0.0.1 --port 102 --discover
```

### 3. 一键编译独立执行二进制

```bash
# 编译命令行独立二进制
dart compile exe bin/client.dart -o build/iec61850_client_cli

# 编译 Linux Desktop Release 安装包
flutter build linux --release --no-tree-shake-icons
```

---

## 🧪 自动化测试与联合回环自测

本项目自带完备的自动化测试体系，包括基础单元测试以及与 `iec61850_server` 的**全流程闭环联合自测**：

### 1. 运行单元与组件测试
```bash
flutter test
```
*涵盖：TPKT/COTP 帧封装解析、ASN.1 BER TLV 编解码、MMS 浮点/布尔/UTC/品质转换、SCL ICD 解析、GOOSE 解码等。*

### 2. 执行端到端闭环自测试 (`bin/verify_client.dart`)
自测脚本会自动拉起后台 `iec61850_server` 并在动态端口上完成 13 项严苛的双向互通检验：
```bash
dart run bin/verify_client.dart
```

**测试流程包括：**
1. 启动 IEC 61850 服务端守护进程
2. 初始化客户端引擎并绑定 SCL 模型 (102 个变量, 12 个 RCB)
3. 建立 TCP Socket，完成 COTP CR/CC 协商与 ACSE AARQ/AARE 握手
4. MMS `GetNameList` 在线模型动态拓扑发现
5. MMS `Read` 单点及遥测数据读取
6. MMS `Write` 遥信/遥调数据写入
7. SBO / Direct 双模遥控操作
8. 报告控制块使能 (`RptEna=true`) 与总召唤 (`GI`)
9. 接收并解析服务端推送的突发 `InformationReport` 数据流
10. MMS 文件服务 `FileDirectory` 目录查询
11. GOOSE 接收机以太网报文解码与结构校验
12. 客户端正常断开与资源安全释放
13. 服务端后台进程正常注销

---

## 📄 授权许可
本项目基于 MIT License 授权开源使用。
