[English](README.md) | [简体中文](README_zh.md)

# Modbus Master Emulator (MME - Flutter & Dart)

本工程是基于对 `ModbusMasterEmulator (MME)` 进行逆向分析与通信协议拆解，使用 **Flutter & 纯 Dart** 完全自主实现的现代化工业级 **Modbus 主站 (客户端) 模拟仿真器**。

![Modbus Master GUI](../docs/images/screenshot_modbus_master.png)

---

## 🌟 核心功能特性

### 1. 完备的通信协议支持
- **Modbus TCP**：标准以太网 MBAP 报文头（事务元组、协议标识、长度、从机UnitID）。
- **Modbus RTU over TCP / 串行 RTU**：完整支持标准 16 位 CRC 校验算法（多项式 `0xA001`，低字节优先）。
- **Modbus ASCII**：完整支持纵向冗余校验 (LRC 校验)。
- **内置零依赖虚拟从站 (Virtual Modbus Slave)**：
  - 即使不外接任何物理 PLC 或硬件设备，打开应用即可立即进行全功能采集、写入、轮询和监控测试！
  - 内置真实电力遥测数据（A/B/C 三相电压、电流、频率、有功功率、变压器温度、开关分合遥信等）。

### 2. 覆盖所有 Modbus 标准功能码
| 功能码 (FC) | 协议名称 | 支持操作 |
|---|---|---|
| **FC 01 (0x01)** | Read Coils (读线圈状态 0x) | 批量/单点读取，支持一键开关切换 |
| **FC 02 (0x02)** | Read Discrete Inputs (读离散输入 1x) | 批量/单点读取 |
| **FC 03 (0x03)** | Read Holding Registers (读保持寄存器 4x) | 批量读取、表格双击直接修改写入 |
| **FC 04 (0x04)** | Read Input Registers (读输入寄存器 3x) | 批量读取模拟量 |
| **FC 05 (0x05)** | Write Single Coil (写单个线圈) | 单个线圈置位/复位 (ON/OFF) |
| **FC 06 (0x06)** | Write Single Register (写单个保持寄存器) | 单个寄存器数值写入 (十进制/0xHex) |
| **FC 15 (0x0F)** | Write Multiple Coils (写多个线圈) | 批量线圈写入 |
| **FC 16 (0x10)** | Write Multiple Registers (写多个保持寄存器) | 批量连续寄存器写入 |
| **FC 22 (0x16)** | Mask Write Register (掩码写寄存器) | AND / OR 掩码位级操作 |
| **FC 08 (0x08)** | Diagnostics (串行诊断) | 回显与通信诊断测试 |
| **FC 17 (0x11)** | Report Slave ID (报告从机设备标识) | 获取从站设备型号及运行状态 |

### 3. 多从站 (Multi-Slave) 与多任务组树形架构 (兼容 MME)
- 支持多从机配置（Slave ID 1 ~ 247），每个从机拥有独立的扫描周期（Scan Rate）与地址基数设置：
  - `0-based`：协议原生 00000 起始
  - `1-based`：自然计数 00001 起始
  - `PLC标准`：40001 / 30001 / 10001 标称起始
- 每个从机下可挂载多个**寄存器任务组 (Register Group)**，支持独立启用/禁用轮询、修改点数与地址。

### 4. 完整的 4 种工业字节序 (Endianness) 与全数据格式转换
- **字节序支持**：
  - `ABCD` (高字优先 / 大端 Big-Endian)
  - `CDAB` (低字优先 / 字交换 Little-Endian Word Swap)
  - `BADC` (字节交换 Byte Swap)
  - `DCBA` (低字优先 / 小端 Little-Endian)
- **数据格式支持**：
  - 16位十六进制 (`Hex16`)、16位二进制 (`Bin16`)
  - 16位有符号整型 (`Int16`)、16位无符号整型 (`UInt16`)
  - 32位有符号整型 (`Int32`)、32位无符号整型 (`UInt32`)
  - 32位单精度浮点数 (`Float32 IEEE-754`)
  - 64位有符号整型 (`Int64`)、64位双精度浮点数 (`Double64`)
  - ASCII 字符串

### 5. Wireshark 级别实时报文分析仪 (Traffic Sniffer)
- 毫秒级精度抓包，直观显示发送 (TX) 与接收 (RX) 流向。
- 显示目标主机、功能码、说明、原始十六进制字节流、往返耗时（RTT）。
- 支持报文暂停、搜索过滤、清空、一键复制完整十六进制、协议分段树状解析。

### 6. 辅助工程工具箱
- **CRC-16 & LRC 校验计算器**：输入任意十六进制数据流，实时生成 CRC16 (低/高字节) 与 LRC，并一键复制带有校验码的完整 RTU 帧。
- **数据格式与字节序转换器**：输入浮点数或整型，直观对比 4 种字节序的 Hex Words 与二进制排列。
- **从站与点号自动扫描器**：指定 Unit ID 范围 (如 1..32) 或寄存器地址范围，一键探测在线设备。
- **高频稳定性与延迟基准压测**：测试从机设备的吞吐量、丢包率、最小/最大/平均往返时延 (ms)。

### 7. 实时遥测动态趋势曲线
- 内置针对遥测点位的实时波形曲线图，动态直观展示数据波动情况。

### 8. 工程文件持久化 (兼容 MME `workspace_v3.json`)
- 自动保存工程配置文件至 `~/.local/share/modbus_master/workspace.json`。
- 自动兼容原版 MME 存储路径 `~/.local/share/MODBUS_MASTER_EMULATOR/workspace_v3.json`。

---

## 🚀 运行与构建方式

### 方式 A：运行桌面 GUI 图形界面
```bash
cd modbus_master
flutter run -d linux
```
或直接运行已编译生成的 Linux 可执行程序：
```bash
./build/linux/x64/release/bundle/modbus_master
```

### 方式 B：运行独立命令行终端 (CLI REPL)
本工程提供无需图形界面的纯终端交互式控制台，支持原生 Linux 独立运行：
```bash
./build/modbus_master_cli
```
或使用 Dart SDK 运行：
```bash
dart run bin/master.dart
```

**CLI 常用命令：**
- `r3 <slaveId> <addr> <count>`：读保持寄存器 (如 `r3 1 0 10`)
- `r1 <slaveId> <addr> <count>`：读线圈 (如 `r1 1 0 8`)
- `w5 <slaveId> <addr> <0|1>`：写单个线圈 (如 `w5 1 2 1`)
- `w6 <slaveId> <addr> <value>`：写单个保持寄存器 (如 `w6 1 0 1234`)
- `w16 <slaveId> <addr> <v1> <v2>...`：批量写保持寄存器 (如 `w16 1 10 100 200 300`)
- `crc <hex>`：计算 CRC16 (如 `crc 01 03 00 00 00 0A`)
- `convert <float>`：转换浮点数四种字节序 (如 `convert 220.5`)
- `virtual`：切换为本地虚拟从站模式

### 方式 C：运行自动化全功能验证套件
```bash
dart run bin/verify_master.dart
```

### 方式 D：运行 Flutter 单元测试
```bash
flutter test
```

---

## 📂 源码目录结构

```
modbus_master/
├── bin/
│   ├── master.dart                 # 交互式 CLI REPL 控制台
│   └── verify_master.dart          # 自动化全功能验证测试脚本
├── build/
│   └── modbus_master_cli           # 编译生成的高性能独立 Native Linux 二进制文件
├── lib/
│   ├── main.dart                   # Flutter 主入口
│   └── src/
│       ├── models/                 # 数据模型与工程存储
│       │   ├── connection_config.dart # 链路配置 (TCP/RTU/Virtual)
│       │   ├── register_group.dart    # 寄存器采集任务组
│       │   ├── register_model.dart    # 单个点位模型与格式化
│       │   ├── slave_model.dart       # 从站参数与寻址模式
│       │   └── workspace_storage.dart # 工作区存储 (与 MME 互通)
│       ├── protocol/               # Modbus 协议核心引擎 (纯 Dart)
│       │   ├── modbus_client.dart     # Modbus 主站核心客户端
│       │   ├── modbus_crc.dart        # CRC-16 (0xA001) 与 LRC 校验算法
│       │   ├── modbus_data_types.dart # 4 种字节序与多数据类型编解码
│       │   ├── modbus_frame.dart      # ADU 帧编解码 (TCP MBAP / RTU)
│       │   └── modbus_pdu.dart        # 所有功能码 PDU 构建与解析
│       ├── services/               # 核心后台服务
│       │   ├── address_scanner.dart   # 从站与点号自动扫描器
│       │   ├── polling_service.dart   # 周期性自动化轮询服务
│       │   ├── stress_test_service.dart # 高频稳定性压测与时延统计
│       │   ├── traffic_logger.dart    # 报文嗅探与数据包记录器
│       │   └── virtual_slave.dart     # 内置电力遥测虚拟从站模拟器
│       └── ui/                     # 现代化 Flutter 桌面图形界面
│           ├── dialogs/               # 对话框 (写线圈/写寄存器/批量写/编辑从站/编辑组)
│           ├── tabs/                  # 6 大功能选项卡视图
│           │   ├── register_view_tab.dart # 寄存器数据表格主视图
│           │   ├── connection_tab.dart    # 连接配置与从站任务树
│           │   ├── commands_tab.dart      # 功能码直接下发中心
│           │   ├── traffic_tab.dart       # 报文抓包监控视图
│           │   ├── tools_tab.dart         # 辅助工具箱 (CRC/转换/扫描/压测)
│           │   └── chart_tab.dart         # 实时趋势波形曲线
│           └── home_screen.dart       # 主界面框架与 NavigationRail
└── test/
    ├── modbus_test.dart            # 协议与模型自动化单元测试
    └── widget_test.dart            # Flutter 组件渲染测试
```
