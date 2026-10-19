# 工业电力自动化协议仿真系统套件 (Industrial Protocol Simulation Suite)

[English](README.md) | [简体中文](README_zh.md) | [Deutsch](README_de.md) | [Français](README_fr.md) | [Español](README_es.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Русский](README_ru.md) | [العربية](README_ar.md)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows%20%7C%20macOS-blue)](https://flutter.dev/desktop)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

基于 **Flutter & 纯 Dart** 自主研发的跨平台现代化工业电力自动化规约仿真平台，提供统一的 Material 3 高对比度工业质感桌面 GUI、独立无依赖命令行（CLI）引擎以及全流程自动化闭环自测套件。

本项目通过对电力自动化与工业现场总线主流仿真商业软件进行通信协议拆解与逆向重构，完整覆盖变电站自动化、配电自动化及工业现场总线三大核心通信规约，包含 **4 大核心项目体系（共 6 个全功能子系统）**：

1. **[IEC 60870-5-104 电力远动规约套件](#1-iec-60870-5-104-电力远动规约套件)**：
   - 服务端（RTU / 从站）：[iec104_server](iec104_server)（逆向重构自 `IEC104ServerSimulator`）
   - 客户端（Master / 主站）：[iec104_client](iec104_client)（逆向重构自 `IEC104ClientSimulator`）
2. **[Modbus 现场总线模拟套件](#2-modbus-现场总线模拟套件)**：
   - 从站仿真器（MSE）：[modbus_slave](modbus_slave)（逆向重构自 `ModbusSlaveEmulator (MSE)`）
   - 主站模拟器（MME）：[modbus_master](modbus_master)（逆向重构自 `ModbusMasterEmulator (MME)`）
3. **[IEC 61850 MMS & GOOSE 服务端模拟器](#3-iec-61850-mms--goose-服务端模拟器)**：
   - 服务端仿真器：[iec61850_server](iec61850_server)（逆向重构自 `IEC61850ServerSimulator`）
4. **[IEC 61850 MMS & GOOSE 客户端模拟器](#4-iec-61850-mms--goose-客户端模拟器)**：
   - 客户端模拟器：[iec61850_client](iec61850_client)（逆向重构自 `IEC61850ClientSimulator`）

---

## 🌐 17 种专业语言国际化 (i18n)

全部 6 款工业仿真软件（IEC 104 服务端/客户端、Modbus 主站/从站、IEC 61850 服务端/客户端）均已实现深度的运行时多语言切换，采用电力自动化、SCADA、变电站自动化（IEC 61850 MMS/GOOSE/SCL）标准行业术语：

支持语言清单：
- 🇸🇦 **阿拉伯语 (ar-SA)** (العربية - 支持动态 RTL 镜像排版)
- 🇩🇪 **德语 (de-DE)** (Deutsch)
- 🇺🇸 **英语 (en-US)** (English - 默认回退语言)
- 🇪🇸 **西班牙语 (es-ES)** (Español)
- 🇫🇷 **法语 (fr-FR)** (Français)
- 🇮🇳 **印地语 (hi-IN)** (हिन्दी)
- 🇮🇩 **印尼语 (id-ID)** (Bahasa Indonesia)
- 🇮🇹 **意大利语 (it-IT)** (Italiano)
- 🇯🇵 **日语 (ja-JP)** (日本語)
- 🇰🇷 **韩语 (ko-KR)** (한국어)
- 🇵🇱 **波兰语 (pl-PL)** (Polski)
- 🇧🇷 **葡萄牙语（巴西）(pt-BR)** (Português do Brasil)
- 🇷🇺 **俄语 (ru-RU)** (Русский)
- 🇹🇭 **泰语 (th-TH)** (ไทย)
- 🇹🇷 **土耳其语 (tr-TR)** (Türkçe)
- 🇻🇳 **越南语 (vi-VN)** (Tiếng Việt)
- 🇨🇳 **简体中文 (zh-CN)** (简体中文)

> 启动时自动读取操作系统默认语言，如未匹配或未支持则自动回退至英语（en-US）。各应用界面右上角均提供地球仪语言切换器，支持实时无缝切换。

---

## 🎨 统一无边框工业桌面 GUI 设计

- **应用品牌图标**：每款软件头部左上角均嵌入专属协议 Logo 图标。
- **自定义无缝窗口控制区**：隐藏操作系统原生粗糙边框与标题栏，在界面右上角原生嵌入最小化、最大化/还原、关闭控制按钮，浑然一体。
- **全局窗口拖拽移动**：标题栏区域任意可拖动，支持多屏幕无缝拖拽移动。
- **黑白高对比度主题**：深色工业模式 / 浅色办公模式一键切换并自动持久化。

---

## 🖥️ 6 大工业仿真软件全景图鉴 (UI Gallery)

| 系统套件 | 协议规约角色 | 软件界面视觉预览 |
| :--- | :--- | :--- |
| **[IEC 104 服务端](iec104_server)** | IEC 60870-5-104 从站 / RTU | [![IEC 104 Server](docs/images/screenshot_iec104_server.png)](iec104_server) |
| **[IEC 104 客户端](iec104_client)** | IEC 60870-5-104 主站 / 调度中心 | [![IEC 104 Client](docs/images/screenshot_iec104_client.png)](iec104_client) |
| **[Modbus 从站仿真器](modbus_slave)** | Modbus TCP / RTU / UDP 从机 (MSE) | [![Modbus Slave](docs/images/screenshot_modbus_slave.png)](modbus_slave) |
| **[Modbus 主站模拟器](modbus_master)** | Modbus TCP / RTU / UDP 主机 (MME) | [![Modbus Master](docs/images/screenshot_modbus_master.png)](modbus_master) |
| **[IEC 61850 服务端](iec61850_server)** | IEC 61850 MMS / GOOSE / SCL 从站 | [![IEC 61850 Server](docs/images/screenshot_iec61850_server.png)](iec61850_server) |
| **[IEC 61850 客户端](iec61850_client)** | IEC 61850 在线模型自发现与监控主站 | [![IEC 61850 Client](docs/images/screenshot_iec61850_client.png)](iec61850_client) |

---

## 🏗️ 整体架构与通信总览

```mermaid
flowchart TB
    subgraph Suite["工业电力自动化规约仿真系统套件 (Flutter & Dart)"]
        subgraph Substation["变电站站控层与过程层 (IEC 61850)"]
            S61850["IEC 61850 服务端 (iec61850_server)<br/>• SCL (ICD/CID/SCD) 解析<br/>• MMS 服务器 (RFC1006/COTP/ACSE)<br/>• GOOSE 8-1 组播发布状态机<br/>• 6种曲线数学仿真"]
            C61850["IEC 61850 客户端 (iec61850_client)<br/>• MMS 在线动态模型发现<br/>• 测点树与实时监控表<br/>• BRCB/URCB 报告使能与GI<br/>• GOOSE 监听与ASN.1解析"]
            C61850 <== "MMS TCP 102 / GOOSE 0x88B8" ==> S61850
        end

        subgraph Telecontrol["调度远动通信层 (IEC 60870-5-104)"]
            S104["IEC 104 服务端 (iec104_server)<br/>• APCI 滑动窗口 (I/S/U)<br/>• ASDU 遥信/遥测/遥控/脉冲<br/>• 总召唤 / 时钟同步 / 突发推送<br/>• 曲线仿真与离线报文剖析"]
            C104["IEC 104 客户端 (iec104_client)<br/>• 测点底账监视库<br/>• 总召唤 / 遥控预置执行<br/>• 设定值调节与时钟同步<br/>• 实时报文流水与过滤"]
            C104 <== "TCP 2404 (APCI + ASDU)" ==> S104
        end

        subgraph Fieldbus["现场仪表与自动化总线 (Modbus)"]
            MSlave["Modbus 从站 (modbus_slave - MSE)<br/>• 多连接下独立从机架构<br/>• TCP / UDP / 纯POSIX串口RTU<br/>• FC01~FC23 全功能码支持<br/>• EaseFunction 动态波形仿真"]
            MMaster["Modbus 主站 (modbus_master - MME)<br/>• 多从机 / 多任务组轮询<br/>• 内置免硬件虚拟从站<br/>• 4种字节序 (ABCD/CDAB/BADC/DCBA)<br/>• CRC16 & LRC 校验工具箱"]
            MMaster <== "TCP 502 / RTU 串口 / UDP" ==> MSlave
        end
    end
```

---

## 🌟 四大核心项目系统详解

### 1. IEC 60870-5-104 电力远动规约套件

深度逆向与重构商业版 `IEC104ServerSimulator` 与 `IEC104ClientSimulator`，实现标准电力远动调度主站与子站通信闭环。

- **子工程路径**：
  - 服务端：[iec104_server](iec104_server)
  - 客户端：[iec104_client](iec104_client)

#### 📸 软件界面与运行实况

##### IEC 104 服务端 (RTU / 从站仿真器)
![IEC 104 服务端仿真器](docs/images/screenshot_iec104_server.png)
> **界面概览**：支持多监听服务实例（如 2404 端口主调、备调）、多从站公共地址 (COA) 站点管理；实时配置 APCI 链路参数（$t_0..t_3$ 超时定时器及 $k, w$ 滑动窗口确认机制），并集成一键仿真自测与客户端会话监视。

##### IEC 104 客户端 (Master / 主站调试工具)
![IEC 104 客户端模拟器](docs/images/screenshot_iec104_client.png)
> **界面概览**：直观管理目标服务端连接配置与通信状态；支持 `STARTDT` / `STOPDT` / `TESTFR` 链路握手控制，一键发送总召唤 (`C_IC_NA_1`)、时钟同步 (`C_CS_NA_1`) 和电能量脉冲召唤，提供开机自动激活与周期总召等自动化策略。

- **协议完整覆盖**：
  - **APCI 链路控制**：I 格式（序号 $N(S), N(R)$ 滑动窗口）、S 格式（监视确认）、U 格式（`STARTDT`, `STOPDT`, `TESTFR` 链路握手，参数 $k, w, t_0..t_3$ 可调）。
  - **监视方向 ASDU**：单/双点遥信（Type 1, 3, 30, 31）、步位置（Type 5, 32）、32位二进制串（Type 7, 33）、归一化/标度化/短浮点遥测（Type 9, 11, 13, 34, 35, 36）、电能量累计量脉冲（Type 15, 37）、初始化结束（Type 70）。
  - **控制方向 ASDU**：单/双命令遥控（Type 45, 46，支持预置选择 Select 与执行 Execute 两步控）、步调节（Type 47）、短浮点设定值（Type 50）、总召唤（Type 100）、电能量召唤（Type 101）、读单点（Type 102）、时钟同步（Type 103，CP56Time2a 绝对时标）。
- **特色功能**：
  - 内置工业级 EaseFunction 曲线发生器，支持遥测正弦波、方波、阶梯波平滑数值变动。
  - Wireshark 级毫秒报文流水查看器与离线原始 16 进制报文解析器（Parser）。

---

### 2. Modbus 现场总线模拟套件

基于商业版 `ModbusSlaveEmulator (MSE)` 与 `ModbusMasterEmulator (MME)` 逆向重构打造，解决传统 Modbus 工具界面陈旧、无法仿真动态波形和配置不灵活的问题。

- **子工程路径**：
  - 从站（MSE）：[modbus_slave](modbus_slave)
  - 主站（MME）：[modbus_master](modbus_master)

#### 📸 软件界面与运行实况

##### Modbus 从站仿真器 (Modbus Slave Emulator - MSE)
![Modbus 从站仿真器](docs/images/screenshot_modbus_slave.png)
> **界面概览**：清晰呈现线圈、离散输入、保持寄存器与输入寄存器监控表；支持单字、双字数值类型解析与批量填充；独创动态波形仿真引擎（正弦波、三角波、线性递增、随机波动），无需外接硬件即可模拟真实传感器信号。

##### Modbus 主站模拟器 (Modbus Master Emulator - MME)
![Modbus 主站模拟器](docs/images/screenshot_modbus_master.png)
> **界面概览**：多从机多任务组轮询主控台，支持单次扫描与连续轮询；提供 16 位 Binary 二进制位段直观显示与修改；支持 `ABCD` (大端)、`CDAB` (小端字交换)、`BADC` (字节交换)、`DCBA` (小端) 四大工业字节序一键切换。

- **多连接与层级架构**：
  - **严格按连接组织从站**（`Connection -> Slaves -> Groups`，非全局从站模式），每个物理/网络链路拥有独立的从站地址空间。
  - **全链路通信支持**：
    - **Modbus TCP**（支持多客户端并发连接，默认 502/5020）。
    - **Modbus RTU 物理串口**（基于 Linux POSIX `libc.so.6` FFI 零外部 C 库依赖，支持波特率、数据位、校验位、停止位自定）。
    - **Modbus RTU over TCP**（网络链路承载 CRC-16 串行帧）。
    - **Modbus UDP**（轻量级无连接通讯）。
- **全功能码支持**：
  - 覆盖 FC 01（读线圈）、FC 02（读离散输入）、FC 03（读保持寄存器）、FC 04（读输入寄存器）、FC 05（写单线圈）、FC 06（写单寄存器）、FC 08（诊断）、FC 15（写多线圈）、FC 16（写多寄存器）、FC 17（从机标识）、FC 22（屏蔽写）、FC 23（读写多个寄存器）。
- **动态曲线生成器与波形画布**：
  - 为每个寄存器独立配置缓动算法：正弦波、三角波、方波、锯齿波、累加计数、随机游走、高阶五次方缓动。
  - 内置 Canvas 动态波形实时预览。
- **工业数据处理**：
  - 完整支持 4 种工业字节序：`ABCD` (大端)、`CDAB` (小端字交换)、`BADC` (字节交换)、`DCBA` (小端)。
  - 主站内置**免硬件虚拟从站**、CRC-16 / LRC 计算器及字节序转换工具箱。

---

### 3. IEC 61850 MMS & GOOSE 服务端模拟器

参考商业版 `IEC61850ServerSimulator` 构建的纯 Dart 规约服务端，无需编译任何第三方 C 动态库即可在全平台运行。

- **子工程路径**：[iec61850_server](iec61850_server)

#### 📸 软件界面与运行实况

![IEC 61850 服务端仿真器](docs/images/screenshot_iec61850_server.png)
> **界面概览**：左侧提供数据模型树与测点快速检索；中央展示选中数据对象（DO/DA）的实时运行数值、品质码（Quality）与时标；支持对模拟量进行正弦波等数学波形发生；右侧展示标准变电站 SCL 层级与元数据 CDC 属性词典。

- **全协议栈自研实现**：
  - **Layer 4-7**：RFC 1006 TPKT、ISO 8073 COTP（Class 0 CR/CC/DT）、ISO 8650 ACSE（AARQ/AARE）、ISO 9506 MMS（ASN.1 BER TLV 编解码器）。
  - **MMS 服务**：
    - `GetNameList`：支持 VMD / 域名（Logical Device）作用域查询数据对象与 DataSet。
    - `Read`：单点、批量及 NamedVariableList（DataSet）读取。
    - `Write`：写布尔、整型、浮点、UTC 时标、品质码；支持 `Oper.ctlVal` 与 `SBO` 遥控。
    - `InformationReport`：针对使能的 BRCB/URCB 推送未确认报告（严格遵循 `RptEna` 与 `bufTime` 抑制）。
    - `MMS File Services`：支持 `FileDirectory` 目录查询、`FileOpen` 打开、`FileRead` 分块读取、`FileClose` 关闭、`FileDelete` 删除（用于故障录波 COMTRADE 下载）。
- **GOOSE (IEC 61850-8-1)**：
  - 工业级以太网 EtherType `0x88B8` 报文封装与 `allData` 结构化编码。
  - 支持 `stNum` 状态跳变、`sqNum` 序号递增与**指数退避（Exponential Backoff）重发机制**。
  - 界面一键触发变位快速重发。
- **SCL (IEC 61850-6) XML 快速解析器**：
  - 支持 ICD, CID, SCD, SSD 配置文件；
  - 递归展开 `DataTypeTemplates`（LNodeType, DOType, DAType, EnumType）至具体的叶子数据属性。
  - 内置 9 套标准示例模型（涵盖保护、测量、控制、GOOSE、风电 61400-25、定值切换等）。

---

### 4. IEC 61850 MMS & GOOSE 客户端模拟器

参考商业版 `IEC61850ClientSimulator` 构建的纯 Dart MMS & GOOSE 调试客户端。

- **子工程路径**：[iec61850_client](iec61850_client)

#### 📸 软件界面与运行实况

![IEC 61850 客户端模拟器](docs/images/screenshot_iec61850_client.png)
> **界面概览**：支持变电站在线动态模型发现（Online Discovery）；以树状与列表形式展示 IED 模型、FC 功能约束、实时采集数值与更新时标；提供单点读写测试、遥控选择与执行 (SBO) 控制面板、BRCB/URCB 报告管理及局域网 GOOSE 报文监听。

- **多连接管理与持久化**：
  - 顶部多连接下拉切换，支持独立配置 IP、端口、TSAP 与关联离线模型。
  - 配置自动持久化至本地存储。
- **7 大功能模块视图**：
  1. 🌲 **模型浏览器 (Model Explorer)**：树状展开 IED/LD/LN/DO/DA，支持单点详情查询、实时刷新、值修改及 SBO 遥控控制面板（带倒计时锁定与解除）。
  2. 📊 **数据监视表 (Data Monitor)**：测点批量监控表格，支持自定周期轮询、品质码解析 (Good/Invalid/Overflow/Test)、数值变动高亮。
  3. 📑 **报告控制块 (Reports)**：BRCB/URCB 控制块列表，可在线启用/停用 (`RptEna`)、总召唤 (`GI`)、触发选项配置，并提供动态未确认报告接收流 (`InformationReport`) 列表。
  4. 🦢 **GOOSE 报文监视 (GOOSE Monitor)**：捕获局域网 GOOSE 广播报文，展示状态号/顺序号、报文详情与 Raw Hex Dump。
  5. 📁 **定值与文件服务 (Files & Settings)**：浏览并下载变电站远端 COMTRADE 录波文件 (`.cfg`, `.dat`)，切换定值区 (`ActSG`)。
  6. 🌐 **网络报文嗅探 (Traffic Sniffer)**：Wireshark 级别报文记录器，展示时间戳、方向 (TX/RX)、协议分层、服务名称及 Hex + ASCII 双栏对照。
  7. 🛠️ **SCL 离线工具与词典 (SCL Tools & Dictionaries)**：内置 9 套标准 SCL 模型，提供 LN、DO、DA、CDC 中英文双语速查词典。

---

## 📊 子工程与产物矩阵

| 子工程 | 规约角色 | 界面形态 | 独立 CLI 二进制 | 发行包路径 |
| :--- | :--- | :--- | :--- | :--- |
| [iec104_server](iec104_server) | IEC 104 从站 / RTU | Flutter Linux / Web | `build/iec104_server` | `iec104_server/build/linux/x64/release/bundle/` |
| [iec104_client](iec104_client) | IEC 104 主站 / 客户端 | Flutter Linux / Web | `build/iec104_client` | `iec104_client/build/linux/x64/release/bundle/` |
| [modbus_slave](modbus_slave) | Modbus TCP/RTU 从站 | Flutter Linux | 纯 Dart 服务引擎 | `modbus_slave/build/linux/x64/release/bundle/` |
| [modbus_master](modbus_master) | Modbus TCP/RTU 主站 | Flutter Linux | 纯 Dart 虚拟主站 | `modbus_master/build/linux/x64/release/bundle/` |
| [iec61850_server](iec61850_server) | IEC 61850 MMS/GOOSE 从站 | Flutter Linux | `build/iec61850_server_cli` | `iec61850_server/build/linux/x64/release/bundle/` |
| [iec61850_client](iec61850_client) | IEC 61850 MMS/GOOSE 主站 | Flutter Linux | `build/iec61850_client_cli` | `iec61850_client/build/linux/x64/release/bundle/` |

---

## 🧪 自动化测试与联合回环自测体系

各子工程均配备单元测试与全流程端到端闭环自测脚本：

```bash
# 1. IEC 104 主从闭环回环测试
cd iec104_server && dart run bin/verify_features.dart

# 2. Modbus 从站单元与协议测试
cd modbus_slave && flutter test

# 3. IEC 61850 服务端协议套件测试
cd iec61850_server && dart run bin/verify_server.dart

# 4. IEC 61850 客户端与服务端联合回环自测 (13项全功能验证)
cd iec61850_client && dart run bin/verify_client.dart
```

---

## 🚀 快速启动指南

### 1. 运行桌面原生图形界面

确保已安装 Flutter SDK（3.x 及以上），进入任意子工程目录执行：

```bash
# 以运行 IEC 61850 客户端为例
cd iec61850_client
flutter run -d linux
```

### 2. 运行无头服务器 CLI 命令行模式

所有核心工程均支持零图形化无头运行：

```bash
# 启动 IEC 104 服务端
cd iec104_server && dart run bin/server.dart --port 2404

# 启动 IEC 61850 服务端
cd iec61850_server && dart run bin/server.dart --port 102 --scl assets/examples/server_example_basic_io.icd

# 启动 IEC 61850 客户端并自动在线发现模型
cd iec61850_client && dart run bin/client.dart --ip 127.0.0.1 --port 102 --discover
```

### 3. 一键编译所有 Release 发布产物

```bash
# 编译 Linux 桌面端发行包
flutter build linux --release --no-tree-shake-icons

# 编译独立无依赖二进制
dart compile exe bin/server.dart -o build/server_cli
```

---

## 🤖 GitHub Actions 自动化构建与全平台发布

项目已集成基于 GitHub Actions 的多平台矩阵自动化打包流水线（`.github/workflows/release.yml`）：

* **触发方式**：推送 Git Tag（如 `v1.0.0`）或在 GitHub Actions 页面手动点击 **Run workflow**。
* **支持目标**：
  * 🪟 **Windows (x64)**：自动生成一键安装向导 `*-setup.exe`（内置桌面/开始菜单快捷方式与卸载项）及免安装绿色包 `*-windows-x64.zip`。
  * 🍎 **macOS (Apple Silicon & Intel)**：自动生成直接拖拽安装的 `*-macos.dmg` 镜像（已预置网络通信沙箱权限）。
  * 🐧 **Linux (x64 / amd64 & ARM64 / aarch64 多架构)**：生成一键安装的 `*.deb` 安装包（适配 Ubuntu/Debian/统信UOS/银河麒麟）以及通用绿色包 `*-linux-*.tar.gz`。
* **发布产物**：自动汇总并直接附带至 GitHub Releases 页面，同时输出 SHA-256 完整性校验文件。

---

## 📄 许可协议

本项目基于 [MIT 许可证](LICENSE) 开源。
