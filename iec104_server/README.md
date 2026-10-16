# IEC 60870-5-104 服务端仿真器 (Flutter & Dart 原生实现)

本工程是深入分析与逆向 `IEC104ServerSimulator` 的全部架构、数据模型与协议处理逻辑后，使用 **Flutter & Dart** 进行现代重构的 **IEC 60870-5-104 电力远动从站（RTU / Server）仿真系统**。

支持 **Flutter 桌面 GUI**、**Flutter Web**、**纯 Dart 命令行后台守护进程** 以及 **原生无依赖 Linux 独立二进制** 多种形态运行。

---

## 目录
1. [原工程逻辑分析与架构映射](#1-原工程逻辑分析与架构映射)
2. [支持的 IEC 104 核心协议规范](#2-支持的-iec-104-核心协议规范)
3. [系统功能架构](#3-系统功能架构)
4. [工程目录结构](#4-工程目录结构)
5. [环境要求与准备](#5-环境要求与准备)
6. [运行与构建指南](#6-运行与构建指南)
7. [主站联调与测试验证](#7-主站联调与测试验证)

---

## 1. 原工程逻辑分析与架构映射

原版 `IEC104ServerSimulator` 为基于 .NET + Avalonia UI + `lib60870.dll` 开发的闭源商业仿真器（包含试用期和激活码校验）。通过对其 CLR 元数据（TypeDef、MethodList、#US 用户字符串表以及中文资源包）分析，其核心逻辑抽象如下：

| 原 C# / Avalonia 模块 | 本 Flutter / Dart 实现 | 说明 |
| :--- | :--- | :--- |
| `Connection104ViewModel` / `ConnectionConfig104Model` | `lib/src/server/iec104_server.dart` & `client_session.dart` | 负责 TCP Socket 监听、连接管理、t0/t1/t2/t3 超时和 k/w 确认窗口维护 |
| `StationViewModel` / `StationModel` | `lib/src/server/station.dart` | 管理从站公共地址 (COA)、点位分类与数据库索引 |
| `InterrogationHandler` (Type 100) | `ClientSession._handleGeneralInterrogation` | 响应总召唤：发送激活确认 (COT=7) -> 逐组遍历发送全站点位 (COT=20) -> 发送激活终止 (COT=10) |
| `CounterInterrogationHandler` (Type 101) | `ClientSession._handleCounterInterrogation` | 响应电能量召唤：ActCon (COT=7) -> 遍历遥脉电能量点 (COT=37) -> ActTerm (COT=10) |
| `ReadHandler` (Type 102) | `ClientSession._handleReadCommand` | 响应主站单点读取命令，回复当前点位值 (COT=5) |
| `ClockSynchronizationHandler` (Type 103) | `ClientSession._handleClockSynchronization` | 响应对时命令，校验 CP56Time2a 并回送 ActCon (COT=7) |
| `AsduHandler` (Types 45..64) | `ClientSession._handleControlCommand` | 遥控及设定值命令处理：支持预置/选择 (Select) 与 执行 (Execute)，执行后自动修改站内点位并触发突发上送 |
| `AutoChangeInformationObject` / `EaseFunctions` | `lib/src/server/ease_functions.dart` | 提供正弦波、递增锯齿、随机波动、方波等曲线仿真 |
| `CommunicatingTrafficWindow` | `lib/src/ui/tabs/traffic_tab.dart` | 毫秒级通信报文收发流水与字段拆解剖析 |
| `IEC104FrameParserWindow` | `lib/src/ui/tabs/parser_tab.dart` & `bin/frame_parser.dart` | 离线报文十六进制结构化拆解分析工具 |

---

## 2. 支持的 IEC 104 核心协议规范

### 2.1 APCI 帧格式支持
* **I 格式 (信息传输帧)**：包含发送序列号 $N(S)$ 与接收序列号 $N(R)$（15 位循环计数），按标准处理滑动窗口 $k$ 与最新确认阈值 $w$。
* **S 格式 (编号监视功能)**：接收帧达到 $w$ 或超时 $t2$ 时，自动回复 S 确认帧 `68 04 01 00 <NR_low> <NR_high>`。
* **U 格式 (未编号控制功能)**：
  * `STARTDT act` (0x07) / `STARTDT con` (0x0B) —— 数据传输激活与确认
  * `STOPDT act` (0x13) / `STOPDT con` (0x23) —— 数据传输停止与确认
  * `TESTFR act` (0x43) / `TESTFR con` (0x83) —— 链路测试与心跳保活

### 2.2 支持的 ASDU 类型标识

#### 监视方向 (遥信 / 遥测 / 遥脉 / 保护事件)
* `M_SP_NA_1` (Type 1)：单点遥信 (开/分、合)
* `M_SP_TA_1` (Type 2)：带 CP24 时标单点遥信
* `M_DP_NA_1` (Type 3)：双点遥信 (00:不确定, 01:分, 10:合, 11:故障)
* `M_DP_TA_1` (Type 4)：带 CP24 时标双点遥信
* `M_ST_NA_1` (Type 5)：步位置信息 / 变压器分接头档位 (-64..63)
* `M_BO_NA_1` (Type 7)：32位二进制串
* `M_ME_NA_1` (Type 9)：归一化测量值 (-1.0 ~ +1.0)
* `M_ME_NB_1` (Type 11)：标度化测量值 (-32768 ~ +32767)
* `M_ME_NC_1` (Type 13)：短浮点数测量值 (IEEE 754 float32)
* `M_IT_NA_1` (Type 15)：累计量 / 电能量脉冲 (32位计数器 + 进位/校验标识)
* **CP56Time2a 时标版**：
  * `M_SP_TB_1` (Type 30)：带 CP56 绝对时标单点遥信
  * `M_DP_TB_1` (Type 31)：带 CP56 绝对时标双点遥信
  * `M_ST_TB_1` (Type 32)：带 CP56 绝对时标步位置
  * `M_BO_TB_1` (Type 33)：带 CP56 绝对时标32位串
  * `M_ME_TD_1` (Type 34)：带 CP56 绝对时标归一化遥测
  * `M_ME_TE_1` (Type 35)：带 CP56 绝对时标标度化遥测
  * `M_ME_TF_1` (Type 36)：带 CP56 绝对时标短浮点遥测
  * `M_IT_TB_1` (Type 37)：带 CP56 绝对时标累计量

#### 控制方向 (遥控 / 遥调 / 设定值)
* `C_SC_NA_1` (Type 45) & `C_SC_TA_1` (Type 58)：单命令 (分/合、选择/执行)
* `C_DC_NA_1` (Type 46) & `C_DC_TA_1` (Type 59)：双命令 (分/合、选择/执行)
* `C_RC_NA_1` (Type 47) & `C_RC_TA_1` (Type 60)：升降步调节命令
* `C_SE_NA_1` (Type 48) & `C_SE_TA_1` (Type 61)：归一化设定值
* `C_SE_NB_1` (Type 49) & `C_SE_TB_1` (Type 62)：标度化设定值
* `C_SE_NC_1` (Type 50) & `C_SE_TC_1` (Type 63)：短浮点数设定值
* `C_BO_NA_1` (Type 51) & `C_BO_TA_1` (Type 64)：32位二进制命令

#### 系统与控制过程
* `M_EI_NA_1` (Type 70)：初始化结束
* `C_IC_NA_1` (Type 100)：总召唤命令 (响应 QOI=20)
* `C_CI_NA_1` (Type 101)：电能量总召唤命令
* `C_RD_NA_1` (Type 102)：读单点命令
* `C_CS_NA_1` (Type 103)：时钟同步命令
* `C_RP_NA_1` (Type 105)：复位进程命令

---

## 3. 系统功能架构

1. **实时突发推送 (Spontaneous / COT=3)**：
   在界面中单击开关合分、修改遥测数值，或由自动变化引擎更新数据时，服务端立即打包生成带有绝对时标 (CP56Time2a) 的突发报文推送至所有在线主站。
2. **自动化工业数据曲线仿真 (Easing Functions)**：
   支持为任意遥测点位绑定函数曲线，模拟电网电压、电流负荷的周期性变化（正弦波、锯齿波、随机游走、阶梯波等）。
3. **通信报文监控中心 (Wireshark 级协议剖析)**：
   以毫秒级时间戳记录收发报文，提供格式化十六进制流水，并支持选中报文展开层级协议树（APCI、ASDU、COT、COA、IOA、品质位、时标等）。
4. **离线报文解析分析器**：
   支持输入连续十六进制、带空格或逗号的报文，进行语法检查与详细字段释义。
5. **多从站设备仿真与工作区自动持久化 (Multi-Station & Workspace Auto-Save)**：
   支持在同一个 104 端口监听下新增多个独立从站设备（每个从站具有独立的公共地址 COA），各从站支持单点添加、批量生成、快速套用变电站/配网工程模板；各从站配置在后台自动原子持久化至本地磁盘（`~/.local/share/iec104_flutter_server/workspace.json`），启动自动恢复。

---

## 4. 工程目录结构

```text
iec104_server/
├── bin/
│   ├── server.dart                  # 独立命令行服务端入口 (CLI Server)
│   ├── frame_parser.dart            # 独立命令行报文解析器 (CLI Parser)
│   └── verify_features.dart         # 核心协议全功能自动化验证套件 (10项完整测试)
├── build/
│   ├── iec104_server                # 预编译的高性能 Linux x64 原生独立二进制 (6.6MB)
│   ├── iec104_parser                # 预编译的 Linux x64 独立报文分析器
│   └── web/                         # 预编译的 Web 端静态部署包
├── lib/
│   ├── main.dart                    # Flutter GUI 应用主入口
│   └── src/
│       ├── protocol/                # IEC 60870-5-104 核心协议编解码层
│       │   ├── apci.dart            # APCI (I/S/U) 格式封装与编解码
│       │   ├── asdu.dart            # ASDU 结构、Type ID、COT 传送原因
│       │   ├── asdu_types.dart      # 品质描述符(QDS)、CP56时标、点位对象定义
│       │   ├── codec.dart           # APDU/ASDU 二进制完整编解码器
│       │   └── parser.dart          # 报文结构化剖析与解释引擎
│       ├── server/                  # 服务端业务与状态机驱动层
│       │   ├── client_session.dart  # 客户端会话状态机、确认窗口与定时器
│       │   ├── iec104_server.dart   # TCP 服务端监听、突发广播与主控制器
│       │   ├── station.dart         # 从站数据库模型 (点位增删改查、默认站)
│       │   ├── ease_functions.dart  # 工业曲线自动变化引擎
│       │   └── traffic_logger.dart  # 通信报文实时流式日志中心
│       └── ui/                      # Flutter Material 3 现代化界面层
│           ├── home_screen.dart     # 主界面外壳与多标签导航
│           ├── tabs/                # 5 大功能标签页
│           │   ├── server_tab.dart  # 服务端网络参数与主站在线列表
│           │   ├── station_tab.dart # 点位监视、控制与突发触发表格
│           │   ├── traffic_tab.dart # 实时通信报文抓包剖析流
│           │   ├── parser_tab.dart  # 交互式报文分析工具
│           │   └── auto_sim_tab.dart# 自动曲线模拟控制台
│           └── dialogs/             # 交互弹窗 (修改数据、添加点位、批量生成)
├── test/
│   ├── protocol_test.dart           # APCI/ASDU/TCP 完整单元测试与联调集成测试
│   └── widget_test.dart             # UI 冒烟测试
├── pubspec.yaml                     # 项目依赖与元数据
└── README.md                        # 本技术与构建文档
```

---

## 5. 环境要求与准备

* **操作系统**：Linux (Ubuntu / Debian / CentOS / Alpine)、Windows 10/11、macOS
* **运行独立二进制**：无任何依赖（无需安装 .NET、Mono、Java、Python 或 Flutter SDK）。
* **源码编译与二次开发**：
  * Flutter SDK: `>= 3.10.0` (推荐 Flutter 3.47.7 / Dart 3.13.5)

国内镜像配置（加速依赖下载）：
```bash
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

---

## 6. 运行与构建指南

### 方式一：直接运行预编译的 Linux 原生独立二进制 (最快推荐)
本工程已经预编译好体积仅 6.6MB 的原生 ELF 可执行文件，无需安装任何 SDK，直接执行：
```bash
# 启动 IEC 104 服务端，默认监听 0.0.0.0:2404
./build/iec104_server

# 指定端口启动
./build/iec104_server --host 0.0.0.0 --port 2404
```
在控制台中支持交互指令：
* `list`：打印当前从站所有点位数据
* `set <ioa> <value>`：修改点位数值并自动突发推送 (COT=3) 给客户端
* `q`：安全退出

同时提供独立报文分析器：
```bash
./build/iec104_parser "68 0e 00 00 00 00 64 01 06 00 01 00 00 00 00 14"
```

---

### 方式二：使用 Dart 源码直接启动命令行服务
```bash
cd iec104_server
dart run bin/server.dart --port 2404
```

---

### 方式三：使用 Flutter 启动现代化 GUI 界面

#### 1. 启动桌面应用 (Linux / Windows / macOS)
```bash
cd iec104_server
flutter run -d linux
```

#### 2. 启动 Web 页面访问
```bash
cd iec104_server
flutter run -d chrome
```

---

### 方式四：执行协议与端到端自动化测试

#### 1. 全协议核心功能自动化验证 (CLI 命令行套件)
工程提供一键式全自动功能测试套件 `bin/verify_features.dart`，涵盖连接、U帧握手、总召、对时、遥控选择与执行、电能量、单点读取、心跳保活、S确认等 10 大核心流程：
```bash
cd iec104_server
dart run bin/verify_features.dart
```
输出示例：
```text
======================================================================
       IEC 60870-5-104 服务端全功能自动化验证套件
======================================================================
[PASS] 1. [连接建立] 虚拟测试主站已连接，分配会话ID: #1
[PASS] 2. [U格式握手] STARTDT 激活成功，服务端回复 STARTDT con 并标记链路激活
[PASS] 3. [总召唤测试] 下发 C_IC_NA_1 (Type 100) 总召唤，服务端成功回复 ActCon (COT=7)、全站遥信/遥测点位数据 (COT=20) 与 ActTerm (COT=10)
[PASS] 4. [时钟对时测试] 下发 C_CS_NA_1 (Type 103) 对时命令，服务端校验时标并回送激活确认 (COT=7)
[PASS] 5. [遥控预置测试] 下发 C_SC_NA_1 (Type 45, IOA=1) 合闸预置选择命令，服务端确认预置成功 (COT=7)
[PASS] 6. [遥控执行测试] 下发 C_SC_NA_1 分闸执行命令，服务端回复确认与终止 (COT=7/10)，站内点位变更为: 0 (分/OFF)，并触发突发上送 (COT=3)
[PASS] 7. [电能量总召] 下发 C_CI_NA_1 (Type 101) 电能量召唤，服务端回送电能脉冲累计量 (COT=37)
[PASS] 8. [单点读取测试] 下发 C_RD_NA_1 (Type 102, IOA=16385) 遥测读命令，服务端回送当前浮点电压值 (COT=5)
[PASS] 9. [测试心跳保活] 下发 TESTFR act 测试链路，服务端立即回复 TESTFR con 确认
[PASS] 10. [S格式监视确认] 发送 S 格式帧确认接收序号 N(R)=4，服务端完成窗口序号对齐
----------------------------------------------------------------------
✔ 全部 10 项 IEC 104 协议核心功能自动验证通过！
======================================================================
```

#### 2. Flutter 单元测试与集成测试
```bash
cd iec104_server
flutter test
```
涵盖 APCI 编码解码、各类型 ASDU 序列化、报文解析以及实际 TCP Socket 连接的端到端自动化测试。

> [!NOTE]
> **关于 Web 环境下的 `ServerSocket.bind` 说明**：
> 现代 Web 浏览器由于沙箱安全限制，不允许页面中的 JavaScript/Wasm 进程直接创建底层的原始 TCP 监听端口（`ServerSocket.bind` 会抛出 `Unsupported operation: ServerSocket.bind`）。
> 本仿真器已做智能自适应处理：
> - **在 Web 端运行时**：自动无缝降级为**虚拟服务端仿真模式（Web Virtual Server Mode）**，在页面上点击【启动虚拟自动验证测试】，即可在浏览器内存中完整模拟主站与从站的 10 项交互，同时在界面报文抓包流水窗口中实时观察全协议报文；
> - **如需对外开放真实 TCP 2404 端口**：请使用 Linux 原生独立二进制 `./build/iec104_server`、命令行 `dart run bin/server.dart` 或桌面应用 `flutter run -d linux`。

---

### 方式五：编译全平台原生分发包

1. **编译原生独立 Linux 可执行文件 (CLI Server)**：
   ```bash
   dart compile exe bin/server.dart -o build/iec104_server
   dart compile exe bin/frame_parser.dart -o build/iec104_parser
   ```
2. **编译 Web 生产环境包**：
   ```bash
   flutter build web --wasm
   # 生成文件位于 build/web/
   ```
3. **编译 Linux 桌面发行版**：
   ```bash
   flutter build linux --release
   # 生成二进制位于 build/linux/x64/release/bundle/
   ```
4. **编译 Windows 发行版 (在 Windows 系统运行)**：
   ```bash
   flutter build windows --release
   ```

---

## 7. 主站联调与测试验证

系统启动后，可以使用配套的 `iec104_client` 或任何标准 IEC 60870-5-104 主站客户端工具进行联调测试（例如 `IEC104ClientSimulator` 或南瑞、国电南自、Wireshark 等）：

1. **连接地址**：`127.0.0.1:2404`（从站公共地址 COA: `1`）
2. **发送连接启动**：客户端发送 `STARTDT act`，服务端自动回复 `STARTDT con` 并上送 `M_EI_NA_1` 初始化结束帧。
3. **总召唤测试 (General Interrogation)**：主站发送 `C_IC_NA_1`（QOI=20），服务端先回复 ActCon (COT=7)，随后按序批量上送遥信、遥测各组数据 (COT=20)，最后发送 ActTerm (COT=10)。
4. **点位遥控测试**：向 IOA `1` 发送 `C_SC_NA_1`（合闸/分闸），服务端校验执行后自动变更站内状态并以 COT=3 突发帧广播给所有监控客户端。
5. **电网曲线自动波动**：服务端后台自动模拟正弦交流电压、三相负荷波动，持续通过 COT=3 突发推送。
