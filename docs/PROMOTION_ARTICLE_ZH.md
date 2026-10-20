# 告别祖传老旧软件：基于 Flutter & 纯 Dart 重构工业电力规约仿真全家桶 (IEC 104 / 61850 / Modbus)

> **项目开源地址**：[https://github.com/orglibs/industrial-protocol-suite](https://github.com/orglibs/industrial-protocol-suite)  
> **官方主页与跨平台下载**：[https://orglibs.github.io/industrial-protocol-suite/](https://orglibs.github.io/industrial-protocol-suite/)  
> **许可协议**：MIT License

---

## 痛点与背景

在电力自动化、变电站综合自动化（SCADA）以及工业物联网（IIoT）现场调试中，工程师每天都离不开各种协议规约仿真软件。

然而，市面上主流的调试工具现状却让人苦不堪言：
1. **技术栈陈旧**：多数仍是十几年前用 MFC、Delphi 或 C++ Builder 编写的祖传软件，高分屏模糊，在 Windows 10/11 上界面粗糙刺眼；
2. **跨平台支持匮乏**：几乎清一色的 Windows 独占，对于日常使用 macOS 或 Linux（统信UOS、银河麒麟）做嵌入式开发的工程师极其不便；
3. **强依赖底层驱动**：安装和运行必须捆绑旧版 WinPcap / Npcap 等底层驱动，权限要求高，甚至可能与现有网卡驱动产生冲突；
4. **功能割裂、各自为战**：IEC 104 找一个软件、Modbus 找另一个软件、IEC 61850 又要找昂贵的闭源商业套件，且主站与从站往往拆开收费。

为了彻底解决这一系列痛点，我们启动了 **Industrial Protocol Suite (IPS)** 项目：基于 **Flutter 3.x & 纯 Dart**，从底层报文拆解到上层图形界面，完整逆向并自主重构了一套覆盖变电站、配电远动与现场总线的**跨平台工业级规约仿真平台**。

---

## 项目体系与架构

系统完整覆盖工业电力自动化三大核心协议，形成 **4 大项目体系、共 6 个全功能子系统（双向主从闭环）**：

```
                   工业电力自动化规约仿真系统套件 (IPS)
 ┌───────────────────────┬───────────────────────┬───────────────────────┐
 │ 变电站自动化 (61850)  │ 调度远动通信 (104)    │ 工业现场总线 (Modbus) │
 ├───────────────────────┼───────────────────────┼───────────────────────┤
 │ • IEC 61850 服务端    │ • IEC 104 服务端      │ • Modbus 从站 (MSE)   │
 │   - MMS TCP 102 服务  │   - RTU 从站模拟      │   - TCP / 串口RTU/UDP │
 │   - GOOSE 8-1 快速组播│   - APCI 滑动窗口控制 │   - FC01~FC23 全功能码│
 │   - SCL (ICD/CID) 解析│   - ASDU 遥测/遥信/遥控│   - 独立多从机架构    │
 │                       │                       │                       │
 │ • IEC 61850 客户端    │ • IEC 104 客户端      │ • Modbus 主站 (MME)   │
 │   - MMS 模型动态自发现│   - 主站调度监控      │   - 多从机多任务轮询  │
 │   - BRCB/URCB 报告处理│   - 总召唤 / 遥控预置 │   - 4种字节序转换     │
 │   - GOOSE 报文监听解析│   - 实时报文流水与过滤│   - 内置硬件免依赖从站│
 └───────────────────────┴───────────────────────┴───────────────────────┘
```

---

## 核心设计与技术亮点

### 1. 100% 纯 Dart 自主规约引擎，告别外部驱动
无论是 IEC 104 的滑动窗口状态机（APCI）、ASDU 编解码，还是 IEC 61850 的 ISO COTP / ACSE / MMS 协议栈与 GOOSE 原始以太网组播，全部采用标准 Dart 二进制流解析实现。
**无需安装 WinPcap、Npcap 或任何第三方 C++ 动态链接库**，解压即可运行，真正做到开箱即用。

### 2. 现代 Material 3 工业无边框桌面交互
- **无缝沉浸式窗口**：彻底隐藏操作系统粗糙的默认标题栏，右上角原生嵌入最小化、最大化、关闭控制，支持全局多屏幕拖拽；
- **高对比度双主题**：深色工业模式（暗光现场不刺眼）与浅色办公模式一键切换并自动持久化；
- **17 种专业语言全覆盖**：支持英语、中文、德语、法语、西班牙语、日语、俄语、阿拉伯语等 17 种语言运行时无缝切换，深度适配电力专业行业术语，并完整支持阿拉伯语从右至左（RTL）镜像排版。

### 3. 内置高精度数学波形与曲线仿真
现场调试常受限于无物理传感器或信号源。套件内各仿真服务端均内置了数学曲线发生器：
- 正弦波 (Sine)
- 方波 (Square)
- 三角波 (Triangle)
- 锯齿波 (Sawtooth)
- 随机游走 (Random Walk)
- 高斯白噪声 (Noise)
能够以毫秒级刷新率动态注入遥测值，逼真模拟电力遥测遥信信号的突发与平稳变化。

### 4. 实时报文流水与逐字段深度剖析
内置轻量级抓包器与报文分析引擎：
- 实时打印 Hex 原始十六进制报文；
- 逐字段展开协议头：APCI 帧类型、收发序列号、ASDU 类型标识符、传送原因、公共地址及信息对象地址（IOA）；
- 具备多重过滤器（按帧类型、时间戳、地址过滤），并支持一键导出排查日志。

---

## 界面预览

| IEC 104 服务端 (RTU) | IEC 104 客户端 (Master) |
| :---: | :---: |
| ![IEC 104 Server](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec104_server.png) | ![IEC 104 Client](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec104_client.png) |

| IEC 61850 服务端 (IED) | IEC 61850 客户端 (SCADA) |
| :---: | :---: |
| ![IEC 61850 Server](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec61850_server.png) | ![IEC 61850 Client](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec61850_client.png) |

| Modbus 从站 (MSE) | Modbus 主站 (MME) |
| :---: | :---: |
| ![Modbus Slave](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_modbus_slave.png) | ![Modbus Master](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_modbus_master.png) |

---

## 跨平台安装包下载

全套软件已通过 GitHub Actions CI/CD 原生构建签名，提供以下平台安装包：
- **Windows (x64)**：`*-setup.exe` 安装向导（自动创建桌面快捷方式及卸载项）及 `*-windows-x64.zip` 免安装绿色版；
- **macOS (Apple Silicon & Intel)**：`*-macos.dmg` 拖拽式安装镜像；
- **Linux (x64 & ARM64)**：`*.deb` 安装包（兼容 Ubuntu, Debian, 统信UOS, 银河麒麟）及便携 `.tar.gz`。

所有发布产物均可在官方下载中心一键获取：  
👉 **[https://orglibs.github.io/industrial-protocol-suite/#downloads](https://orglibs.github.io/industrial-protocol-suite/#downloads)**

---

## 开源协议与交流

本项目采用 **MIT 开源许可证**，无论是学术研究、电力工程现场调试还是二次开发均完全自由。

欢迎在 GitHub 上提出 Issue 或 PR，如果这个项目对你的日常调试有所帮助，别忘了点一颗 ⭐️ **Star** 支持开源！

* **GitHub 仓库**：[https://github.com/orglibs/industrial-protocol-suite](https://github.com/orglibs/industrial-protocol-suite)
* **参与讨论**：[GitHub Discussions](https://github.com/orglibs/industrial-protocol-suite/discussions)
