[English](README.md) | [简体中文](README_zh.md)

# Modbus Slave Emulator (MSE - Flutter & Dart)

本工程是基于对 `ModbusSlaveEmulator (MSE)` 进行逆向分析与通信协议拆解，使用 **Flutter & 纯 Dart** 完全自主实现的现代化工业级 **Modbus 从站 (服务端) 模拟仿真器**。

![Modbus Slave GUI](../docs/images/screenshot_modbus_slave.png)

---

## 🌟 核心功能特性

### 1. 严格按连接组织的多从站与任务组架构 (Connection -> Slaves -> Groups)
- **从站归属于连接（不使用全局模式）**：彻底遵循商业版 MSE 设计，每个连接（Connection）独立拥有各自的从站（Slave）列表与寄存器组配置。
- **支持多连接同时监听**：
  - **Modbus TCP Server**：支持绑定任意 IP (如 `0.0.0.0` 或指定网卡) 与端口 (默认 `502` / `5020`)，支持多个外部主站同时并发连接。
  - **Modbus RTU 物理串口**：基于纯 POSIX `libc.so.6` FFI 零外部依赖实现，支持标准物理串口与虚拟终端 (`/dev/ttyUSB*`、`/dev/ttyS*`、`/dev/pts/*`、`COM*`)，支持波特率、数据位、校验位 (None/Odd/Even) 与停止位自定义。
  - **Modbus RTU over TCP**：TCP 网络链路传输标准 RTU 帧格式 (包含 CRC-16)。
  - **Modbus UDP**：无连接轻量级 Modbus UDP 服务端。
- **从站配置与管理**：
  - 支持从站地址（Slave ID 1 ~ 247）设置与重复校验；
  - 支持从机复制功能（Copy Slave）；
  - **支持应答延迟仿真（Response Delay in ms）**：模拟真实弱网通信或老旧低速 PLC 设备的物理响应延迟。

### 2. 覆盖完整 Modbus 功能码与标准异常响应
| 功能码 (FC) | 协议名称 | 从站处理与交互 |
|---|---|---|
| **FC 01 (0x01)** | Read Coils (读线圈状态 0x) | 返回线圈按位打包字节流，实时响应外部读取 |
| **FC 02 (0x02)** | Read Discrete Inputs (读离散输入 1x) | 返回离散输入按位打包字节流 |
| **FC 03 (0x03)** | Read Holding Registers (读保持寄存器 4x) | 返回 16 位整型/浮点寄存器字数据 |
| **FC 04 (0x04)** | Read Input Registers (读输入寄存器 3x) | 返回输入寄存器模拟量数据 |
| **FC 05 (0x05)** | Write Single Coil (写单个线圈) | 修改从站对应线圈数据并回显 |
| **FC 06 (0x06)** | Write Single Register (写单个保持寄存器) | 写入单个寄存器数据并回显 |
| **FC 08 (0x08)** | Diagnostics (串行诊断) | 支持诊断回显（SubFunction 0x0000）测试 |
| **FC 15 (0x0F)** | Write Multiple Coils (写多个线圈) | 批量更新线圈，严格校验数量与边界 |
| **FC 16 (0x10)** | Write Multiple Registers (写多个保持寄存器) | 批量更新连续保持寄存器数据 |
| **FC 17 (0x11)** | Report Slave ID (报告从机设备标识) | 返回从站设备型号及运行状态指示 |
| **FC 22 (0x16)** | Mask Write Register (屏蔽写寄存器) | 执行 `(Current & AndMask) | (OrMask & ~AndMask)` 位级修改 |
| **FC 23 (0x17)** | Read/Write Multiple Registers (读写多个寄存器) | 先写入目标寄存器，再读取并返回指定数据 |

- **标准异常响应**：
  - `0x01`: 非法功能码 (Illegal Function)
  - `0x02`: 非法数据地址 (Illegal Data Address)
  - `0x03`: 非法数据值 (Illegal Data Value)
  - `0x04`: 从站设备故障 (Slave Device Failure)
  - `0x0A`: 网关路径不可用 (Gateway Path Unavailable，针对未配置从站的请求)

### 3. 数据动态波形仿真 / 缓动曲线引擎 (EaseFunctionConfig / Simulation)
复刻原版 MSE `EaseFunctionConfig` 的全部数学缓动与波形发生能力，可为每个寄存器独立配置动态数据生成器：
- **正弦波 (Sine Wave)**：平滑正弦振荡，模拟交流电网电压、电流波动。
- **三角波 (Triangle Wave)**：线性上升至波峰并线性下降至波谷。
- **方波 (Square Wave)**：高低电平周期交替跳跃。
- **锯齿波 (Sawtooth Wave)**：线性递增至波峰后重置。
- **累加计数 (Increment Counter)**：按指定步长持续累加，到最大值自动回绕。
- **随机波动 (Random Noise / Walk)**：在上下限范围内随机散列生成。
- **五次方缓动 (EaseInQuint / EaseOutQuint / EaseInOutQuint)**：高阶非线性动力学曲线。
- **交互特性**：
  - 内置**动态波形预览 Canvas**，参数调整时直观绘制波形轨迹；
  - 后台周期性平滑更新寄存器数值，主界面表格实时同步刷新；
  - 外部主站轮询采集时，可读取到高拟真度、连续变化的真实工业设备模拟数据。

### 4. 工业四字节序 (Endianness) 与多字组合机制 (Composite Types)
- **字节序转换**：
  - `ABCD`：大端 (Big-Endian / 高字优先)
  - `CDAB`：低字优先 / 字交换 (Little-Endian Word Swap)
  - `BADC`：字节交换 (Byte Swap)
  - `DCBA`：小端 (Little-Endian)
- **数据显示与组合类型**：
  - 16 位整型 (`Int16` / `UInt16`)、十六进制 (`Hex16`)、二进制 (`Bin16`)
  - 32 位整型 (`Int32` / `UInt32`)、32 位单精度浮点 (`Float32 IEEE 754`)
  - 64 位整型 (`Int64`)、64 位双精度浮点 (`Double64 IEEE 754`)
  - ASCII 字符串
- **MSE 组合标识点阵**：复刻 MSE 的多字组合点阵颜色标识，清晰标记 32 位（双字）和 64 位（四字）跨寄存器复合点。

### 5. 交互式数据表格与批量填充
- **寄存器表格（RegisterViewTab）**：
  - 0-based (`00000`)、1-based (`00001`)、PLC 格式 (`40001` / `30001` / `10001`) 地址编号模式；
  - 支持点位别名（Alias）与备注（Comment）；
  - **双击内联直接修改数值**，自动根据当前数据格式校验；
  - 实时显示波形模拟图标与运行状态徽章；
  - 支持关键字模糊检索点号或别名。
- **批量填充对话框（BatchFillDialog）**：
  - 一键整组清零（All 0）；
  - 全部置 1（All 1 / Max）；
  - 设定固定常数（Constant）；
  - 线性递增批量填入（指定起始值与步长）；
  - 随机数值范围填充（指定最小值与最大值）。

### 6. 通信报文抓包监控仪 (TrafficTab)
- 毫秒级时间戳抓包记录，直观标识 `RX (从主站接收)` 与 `TX (向主站应答)` 及 `ERR (异常响应)`；
- 完整十六进制字节流高亮展示与一键复制；
- 协议解析描述（如 `[FC 03] 读保持寄存器: 起始=0, 数量=10 -> 应答 20 字节`）；
- 支持按连接过滤、按收发方向过滤、关键字搜索、暂停/继续、自动滚屏与文本导出。

### 7. 实时动态趋势曲线 (ChartTab)
- 复刻原版 MSE `LiveDataGrowingWindow`；
- 可自由选择任意连接、从站和寄存器点位；
- 5Hz 高频平滑绘制动态曲线，带有极值区间与实时数值徽章。

### 8. 辅助工程工具箱 (ToolsTab)
- **数值 ⇋ 字节转换器**：浮点数、双精度、整型在不同字节序下的十六进制互转；
- **校验算法计算器**：Modbus RTU CRC-16 (多项式 `0xA001`)、Modbus ASCII LRC、Sum 8 实时计算；
- **字符编解码器**：ASCII / UTF-8 字符串与 Hex 字节流互转；
- **串口探测与占用检测**：扫描主机可用物理与虚拟串口设备。

### 9. 工作区存储持久化 (WorkspaceStorage)
- 自动保存工程配置文件至 `~/.local/share/modbus_slave/workspace.json`；
- 兼容原版 MSE 路径 `~/.local/share/MODBUS_SLAVE_EMULATOR/workspace.json`；
- 支持将当前配置一键导出或从外部 JSON 文件导入。

---

## 🚀 运行与使用方式

### 方式 A：运行桌面 GUI 应用程序
直接运行已编译生成的 Linux 可执行安装包：
```bash
./build/linux/x64/release/bundle/modbus_slave
```
或通过 Flutter 源码开发模式运行：
```bash
flutter run -d linux
```

### 方式 B：运行独立命令行从站服务端 (CLI Server)
本工程提供无需图形界面的纯终端服务端程序，可脱离桌面环境在后台或服务器无缝运行：
```bash
# 启动 TCP 从站服务（默认监听 0.0.0.0:5020，并开启波形模拟）
./build/modbus_slave_cli -p 5020 --sim

# 启动串口 RTU 从站服务
./build/modbus_slave_cli -m serial -s /dev/ttyUSB0 -b 9600

# 查看 CLI 命令行帮助
./build/modbus_slave_cli --help
```
也可以使用 Dart SDK 直接运行脚本：
```bash
dart run bin/slave.dart -p 5020 --sim
```

### 方式 C：运行自动化全功能集成测试套件
```bash
dart run bin/verify_slave.dart
```

### 方式 D：运行 Flutter 单元测试
```bash
flutter test
```

---

## 📂 源码目录结构

```
modbus_slave/
├── bin/
│   ├── slave.dart                  # CLI 纯命令行从站服务端入口
│   └── verify_slave.dart           # 全功能自动化端到端网络通信集成测试套件
├── build/
│   ├── modbus_slave_cli            # 编译生成的独立免依赖 Linux Native CLI 可执行程序
│   └── linux/x64/release/bundle/   # Flutter Linux 桌面端 Release 二进制打包目录
│       └── modbus_slave            # 桌面客户端主执行文件
├── lib/
│   ├── main.dart                   # Flutter 应用入口与深色/浅色主题管理
│   └── src/
│       ├── models/                 # 数据模型层 (纯 Dart，跨端脱耦)
│       │   ├── connection_config.dart # 连接配置（包含从站集合与默认工业电站模板）
│       │   ├── slave_model.dart       # 从站配置（地址编号模式、从站ID、应答延迟）
│       │   ├── register_group.dart    # 寄存器组（线圈/离散/保持/输入、批量填充）
│       │   ├── register_model.dart    # 单点模型（别名、数值、多字组合、波形配置）
│       │   ├── simulation_config.dart # 正弦/三角/方波/累加/随机曲线数学模型
│       │   └── workspace_storage.dart # 工作区存储与 MSE 兼容互通
│       ├── protocol/               # Modbus 协议与网络核心引擎
│       │   ├── modbus_crc.dart        # CRC-16 (0xA001) 与 LRC 校验算法
│       │   ├── modbus_data_types.dart # 4 种字节序与多数据类型编解码
│       │   ├── modbus_frame.dart      # ADU 帧编解码与请求数据提取
│       │   ├── modbus_pdu.dart        # 功能码请求与应答 PDU 处理
│       │   ├── modbus_server.dart     # TCP / RTU / UDP 服务端管理与多客户端支持
│       │   ├── modbus_slave_engine.dart # FC 01~23 执行分发与异常应答引擎
│       │   └── serial_port_adapter.dart # 基于 libc FFI 的物理串口非阻塞适配器
│       ├── services/               # 后台核心服务
│       │   ├── simulation_service.dart# 后台波形发生器与缓动步进服务
│       │   └── traffic_logger.dart    # 全局报文总线与收发日志
│       └── ui/                     # 现代化 Flutter 桌面图形界面
│           ├── dialogs/               # 参数对话框 (编辑连接/从站/组/点/批量填充/波形配置)
│           │   ├── batch_fill_dialog.dart
│           │   ├── edit_connection_dialog.dart
│           │   ├── edit_group_dialog.dart
│           │   ├── edit_register_dialog.dart
│           │   ├── edit_slave_dialog.dart
│           │   └── simulation_config_dialog.dart
│           ├── tabs/                  # 5 大功能选项卡视图
│           │   ├── register_view_tab.dart # 寄存器表格监视与内联编辑主视图
│           │   ├── topology_tab.dart      # 连接/从站/寄存器组三栏层级拓扑管理
│           │   ├── traffic_tab.dart       # 报文抓包监控视图
│           │   ├── chart_tab.dart         # 实时数据趋势曲线视图
│           │   └── tools_tab.dart         # 辅助工具箱 (换算/CRC/编码/串口探测)
│           └── home_screen.dart       # 主界面框架与 NavigationRail
└── test/
    └── modbus_slave_test.dart      # 完整协议、模型与波形数学单元测试套件
```

---

## 🔗 主站与从站联合联调测试

本工程与同目录下的 [`modbus_master`](../modbus_master) 形成了完整的 Modbus 生态闭环：
1. 终端 1 启动从站服务端：
   ```bash
   cd modbus_slave
   ./build/modbus_slave_cli -p 5020 --sim
   ```
2. 终端 2 启动主站进行读写轮询或全功能测试：
   ```bash
   cd modbus_master
   dart run bin/verify_master.dart
   ```
双方在标准 Modbus TCP 与 Serial RTU 协议下数据交互毫秒级响应，正弦波等实时波形动态变化无缝穿透传输。
