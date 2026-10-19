[English](README.md) | [简体中文](README_zh.md)

# IEC 60870-5-104 客户端仿真器 (Flutter & Dart 原生实现)

本工程深度参考 `IEC104ClientSimulator` 的完整交互逻辑、ASDU 命令集、连接状态机与点位监视体系，使用 **Flutter & Dart** 重构实现的 **IEC 60870-5-104 电力主站（Client / Master）仿真系统**。

支持 **Flutter Linux 原生桌面 GUI**、**Flutter Web**、**纯 Dart 命令行交互控制台 (REPL)** 以及 **原生无依赖 Linux 独立二进制** 多种形态运行。

![IEC 104 Client GUI](../docs/images/screenshot_iec104_client.png)

---

## 目录
1. [原工程架构分析与功能映射](#1-原工程架构分析与功能映射)
2. [支持的 IEC 104 客户端核心功能](#2-支持的-iec-104-客户端核心功能)
3. [工程目录结构](#3-工程目录结构)
4. [运行与构建指南](#4-运行与构建指南)
5. [与服务端联调测试](#5-与服务端联调测试)

---

## 1. 原工程架构分析与功能映射

原版 `IEC104ClientSimulator` 为基于 .NET + Avalonia + `IEC60870Lib.dll` 开发的闭源商业主站仿真器。经逆向分析其元数据与中文资源包，核心功能对应关系如下：

| 原 C# / Avalonia 模块 | 本 Flutter / Dart 实现 | 功能说明 |
| :--- | :--- | :--- |
| `CreateConnectionWindowViewModel` / `ApduTransport` | `lib/src/client/iec104_client.dart` | 负责 TCP 客户端连接、t0/t1/t2/t3 定时器和 k/w 滑动窗口维护 |
| `StationViewModel` / `InformationObjects` | `lib/src/client/station_data.dart` | 维护所连接变电站 (COA) 的遥信、遥测、遥脉点位数据库及历史变更 |
| `C_IC_NA_1_Window` (Type 100) | `CommandsTab` & `client.sendGeneralInterrogation` | 全站总召唤 (QOI=20) 与分组召唤 |
| `C_CI_NA_1_Window` (Type 101) | `CommandsTab` & `client.sendCounterInterrogation` | 电能量脉冲累计量总召唤与冻结/复位 |
| `C_CS_NA_1_Window` (Type 103) | `CommandsTab` & `client.sendClockSynchronization` | 7 字节 CP56Time2a 时标时钟同步命令 |
| `C_RD_NA_1_Window` (Type 102) | `CommandsTab` & `client.sendReadCommand` | 单点读取命令 (按 IOA 获取最新点位值) |
| `C_SC_NA_1_Window` (Type 45/58) | `CommandsTab` & `client.sendSingleCommand` | 单命令遥控：分/合闸，支持预置选择 (Select) 与 直接执行 (Execute) |
| `C_DC_NA_1_Window` (Type 46/59) | `CommandsTab` & `client.sendDoubleCommand` | 双命令遥控：01分闸 / 10合闸，支持预置/执行 |
| `C_RC_NA_1_Window` (Type 47/60) | `CommandsTab` & `client.sendStepCommand` | 变压器分接头升降步调节命令 (升一步/降一步) |
| `C_SE_NC_1_Window` (Type 50/63) | `CommandsTab` & `client.sendSetpointFloat` | 短浮点数模拟量设定值调节 |
| `C_RP_NA_1_Window` (Type 105) | `CommandsTab` & `client.sendResetProcess` | 复位进程命令 |
| `CommunicatingTrafficWindow` | `lib/src/ui/tabs/traffic_tab.dart` | Wireshark 级通信报文收发流水与协议逐层剖析 |
| `Iec104FrameParserWindow` | `lib/src/ui/tabs/parser_tab.dart` | 离线报文十六进制结构化拆解与解释工具 |

---

## 2. 支持的 IEC 104 客户端核心功能

### 2.1 链路层与 APCI 自动管理
- **U 格式帧处理**：
  - 连接建立后自动发送 `STARTDT act`（数据传输激活），接收并处理服务端的 `STARTDT con`；
  - 支持手动或按需下发 `STOPDT act`（停止数据传输）及 `TESTFR act`（心跳链路保活）；
- **S 格式帧处理**：
  - 自动维护接收序列号 $N(R)$ 与发送序列号 $N(S)$；
  - 当未确认接收 I 帧数达到窗口阈值 $w$（默认 8）或 $t2$ 超时时，自动下发 S 格式确认帧；
- **I 格式帧接收与分发**：
  - 自动解包 ASDU 负载并分发至点位数据中心；
  - 监听自发突发上送报文（COT=3）、总召唤数据（COT=20）、电能量数据（COT=37）、读点响应（COT=5）等。

### 2.2 监视方向 ASDU 数据解析与点位库
- **单点遥信 (M_SP_NA_1 / M_SP_TB_1)**：开/分 (0), 合 (1)
- **双点遥信 (M_DP_NA_1 / M_DP_TB_1)**：01分, 10合, 00不确定, 11故障
- **短浮点遥测 (M_ME_NC_1 / M_ME_TF_1)**：母线电压、出线电流、有功/无功功率等 (float32)
- **归一化遥测 (M_ME_NA_1 / M_ME_TD_1)**：-1.0 ~ +1.0
- **标度化遥测 (M_ME_NB_1 / M_ME_TE_1)**：-32768 ~ +32767
- **电能量累计量 (M_IT_NA_1 / M_IT_TB_1)**：脉冲计数与进位标志
- **步位置信息 (M_ST_NA_1 / M_ST_TB_1)**：变压器档位 (-64..63)
- **二进制串 (M_BO_NA_1 / M_BO_TB_1)**：32 位开关状态位

### 2.3 周期性与自动化任务
- **连接后自动总召唤**（Auto General Interrogation on Connect）
- **周期性总召唤**（支持自定义间隔秒数）
- **周期性时钟同步**（支持自定义间隔秒数）
- **周期性电能量召唤**（支持自定义间隔秒数）

### 2.4 工作区自动持久化与从站管理 (Auto-Save Workspace)
- **多从站管理与批量加点**：支持增加从站、编辑从站公共地址 (COA)、单点新增、批量生成点号、点表导入与导出；
- **配置持久化落盘 (Workspace Auto-Save)**：自动在后台防抖持久化所有从站点表和通信配置至本地磁盘（Linux 路径：`~/.local/share/iec104_flutter_client/workspace.json`）；
- **启动自动恢复 (Auto-Restore)**：软件启动时自动读取上次保存的工作区，完全保留所有自定义从站及点号，无需反复重新配置；
- **手动保存与导入导出**：顶部提供即时保存按钮，点位表提供可视化 JSON 导入/导出，方便跨环境备份与迁移。

---

## 3. 工程目录结构

```text
iec104_client/
├── bin/
│   ├── client.dart                  # 命令行交互式客户端 (REPL 命令行控制台)
│   └── verify_client.dart           # 客户端全功能自动化一键验证套件 (10项测试)
├── build/
│   ├── iec104_client                # 预编译的高性能 Linux x64 原生独立可执行文件
│   ├── linux/x64/release/bundle/    # 预编译的原生 Linux 桌面图形 GUI 发行包
│   └── web/                         # 预编译的 Web 端静态部署包
├── lib/
│   ├── main.dart                    # Flutter 桌面 / Web 应用主入口
│   └── src/
│       ├── client/                  # 客户端核心实现
│       │   ├── iec104_client.dart   # TCP 连接、状态机、命令下发与虚拟仿真模式
│       │   ├── station_data.dart    # 变电站从站与点位数据库模型
│       │   └── traffic_logger.dart  # 报文流水与日志中心
│       ├── protocol/                # IEC 60870-5-104 核心协议库
│       │   ├── apci.dart            # APCI (I/S/U) 格式编解码
│       │   ├── asdu.dart            # ASDU 结构、Type ID、COT 传送原因
│       │   ├── asdu_types.dart      # 品质描述符(QDS)、CP56时标、点位对象
│       │   ├── codec.dart           # 二进制编解码器
│       │   └── parser.dart          # 报文结构化剖析与解释引擎
│       └── ui/                      # 现代化 Material 3 界面
│           ├── home_screen.dart     # 主界面外壳与导航侧边栏
│           └── tabs/                # 5 大功能标签页
│               ├── connection_tab.dart # 连接管理、网络参数与自动化测试
│               ├── points_tab.dart     # 点位监视中心 (分类筛选、实时更新、快捷遥控)
│               ├── commands_tab.dart   # 命令下发中心 (总召/对时/遥控/设定值/读取)
│               ├── traffic_tab.dart    # 通信报文抓包流 (Wireshark 级层级树)
│               └── parser_tab.dart     # 离线十六进制报文分析器
├── test/
│   ├── client_test.dart             # 客户端单元测试与状态机自动化测试
│   └── widget_test.dart             # 界面冒烟测试
├── pubspec.yaml                     # 项目依赖配置
└── README.md                        # 本技术说明文档
```

---

## 4. 运行与构建指南

### 方式一：直接运行已编译的 Linux 桌面原生 GUI（推荐，秒开界面）

```bash
cd iec104_client
./build/linux/x64/release/bundle/iec104_client
```

---

### 方式二：直接运行预编译的 Linux 原生独立命令行程序

无需安装 Flutter 或 Dart SDK，直接执行：
```bash
cd iec104_client
./build/iec104_client --host 127.0.0.1 --port 2404
```
在控制台中提供交互式指令：
- `gi`：下发全站总召唤
- `clock`：下发时钟对时
- `ci`：下发电能量总召
- `sc <ioa> <0|1>`：下发单命令直接执行 (0=分, 1=合)
- `sc-sel <ioa> <0|1>`：下发单命令预置选择
- `dc <ioa> <0|1>`：下发双命令执行
- `read <ioa>`：单点读取当前值
- `list`：打印当前已收录的所有点位值
- `q`：安全退出

---

### 方式三：使用 Flutter 启动调试模式

```bash
cd iec104_client

# 启动 Linux 桌面应用
flutter run -d linux

# 启动 Web 页面
flutter run -d chrome
```

---

### 方式四：运行客户端全功能自动化验证套件

```bash
cd iec104_client
dart run bin/verify_client.dart
```

**测试执行输出：**
```text
======================================================================
       IEC 60870-5-104 客户端全功能自动化验证套件
======================================================================
正在启动 IEC 104 客户端自动化测试流程...

----------------------- 自动化验证测试项 -----------------------
[PASS] 1. [连接创建] 客户端初始化并接入仿真服务 (状态: 已建立TCP连接)
[PASS] 2. [U格式握手] 成功发送 STARTDT act 并收到服务端 STARTDT con 确认，激活链路
[PASS] 3. [总召唤测试] 下发 C_IC_NA_1 (Type 100) 总召唤，收到遥信(3)与遥测(4)，点位入库成功
[PASS] 4. [时钟对时测试] 下发 C_CS_NA_1 (Type 103) 时钟同步命令，服务端回复激活确认 (COT=7)
[PASS] 5. [遥控预置与执行] 下发 C_SC_NA_1 (Type 45, IOA=1) 合闸预置与执行命令，触发突发上送 COT=3
[PASS] 6. [电能量总召] 下发 C_CI_NA_1 (Type 101) 电能量召唤，成功收到遥脉电量值: 12580
[PASS] 7. [单点读取测试] 下发 C_RD_NA_1 (Type 102, IOA=16385)，收到当前点位实时数值反馈
[PASS] 8. [S格式确认测试] 主动下发 S 格式监视确认帧 N(R)=18 对齐接收窗口
[PASS] 9. [测试心跳保活] 下发 TESTFR act 测试保活，收到 TESTFR con 回复
[PASS] 10. [链路释放] 发送 STOPDT act 并正常关闭连接 (状态: 未连接)
----------------------------------------------------------------------
✔ 全部 10 项 IEC 104 客户端核心功能自动验证通过！
======================================================================
```

---

## 5. 与服务端联调测试

本项目可直接与配套的 [`iec104_server`](../iec104_server) 进行端到端本地联调：

1. **终端 A：启动服务端**
   ```bash
   cd iec104_server
   ./build/iec104_server --port 2404
   ```
2. **终端 B：启动客户端 GUI 或 CLI**
   ```bash
   cd iec104_client
   ./build/linux/x64/release/bundle/iec104_client
   # 或运行 CLI:
   ./build/iec104_client --port 2404
   ```
3. 在客户端中点击【建立连接】或输入 `connect`：
   - 客户端发送 `STARTDT act`，服务端回复 `STARTDT con`；
   - 客户端自动下发总召唤 `C_IC_NA_1`，服务端将全站遥信、遥测批量推送入库；
   - 在客户端【点位监视】或【命令下发】中下发遥控命令，服务端执行后即刻通过 COT=3 突发帧广播给客户端，界面即时高亮刷新！
