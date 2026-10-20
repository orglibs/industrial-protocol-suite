#!/usr/bin/env python3
"""
Industrial Protocol Suite (IPS) - Open Source Promotion Automation Script
Supports:
1. One-click open browser with prefilled submission forms (阮一峰周刊, HelloGitHub, V2EX, Reddit, etc.)
2. Copy platform-tailored articles directly to system clipboard (via xclip)
3. Direct API submission to GitHub if a GITHUB_TOKEN is provided
"""

import sys
import os
import urllib.parse
import subprocess
import json

REPO_URL = "https://github.com/orglibs/industrial-protocol-suite"
SITE_URL = "https://orglibs.github.io/industrial-protocol-suite/"

RUANYF_TITLE = "【开源自荐】Industrial Protocol Suite：基于 Flutter & 纯 Dart 的跨平台工业电力规约仿真套件"
RUANYF_BODY = f"""
## 项目介绍
**Industrial Protocol Suite (IPS)** 是一个基于 Flutter 3.x 与纯 Dart 打造的现代化跨平台（Windows / macOS / Linux）工业电力自动化协议仿真系统。

项目通过对电力自动化与工业现场总线主流仿真商业软件进行逆向与自主重构，完整覆盖 IEC 60870-5-104 电力远动、IEC 61850 变电站自动化（MMS / GOOSE）以及 Modbus TCP/RTU 三大核心规约，共包含 6 款全功能客户端与服务端桌面软件及独立 CLI 引擎。

## 核心特性
- **100% 纯 Dart 规约引擎**：底层报文拆解与状态机均为纯 Dart 实现，无 WinPcap 或第三方 C++ 动态库依赖，真正开箱即用；
- **现代 Material 3 工业无边框桌面交互**：沉浸式标题栏、深色工业模式/浅色办公模式持久化切换、支持 17 种国际化语言（含阿拉伯语 RTL 镜像）；
- **内置高精度数学波形仿真**：内置正弦波、方波、随机游走等 6 种动态曲线，免外接物理传感器即可逼真模拟现场遥测变化；
- **全流程闭环自测与自动化打包**：包含主从闭环单元测试与端到端回归自测，由 GitHub Actions 原生构建 Windows、macOS 与 Linux 安装包。

## 相关链接
- 源码仓库：[{REPO_URL}]({REPO_URL})
- 官方主页与下载：[{SITE_URL}]({SITE_URL})
- 许可协议：MIT License
"""

HELLOGITHUB_TITLE = "[开源自荐] Industrial Protocol Suite：基于 Flutter & 纯 Dart 的跨平台工业电力规约仿真套件"
HELLOGITHUB_BODY = f"""
### 项目地址
{REPO_URL}

### 类别
Dart / 工业控制 / 桌面应用

### 项目标题
基于 Flutter & 纯 Dart 的跨平台工业电力规约仿真套件 (IEC 104 / 61850 / Modbus)

### 项目描述
Industrial Protocol Suite 是一套现代化的工业电力自动化规约仿真平台。完整覆盖变电站自动化（IEC 61850 MMS/GOOSE）、配电远动（IEC 104）及现场总线（Modbus TCP/RTU）三大支柱规约，提供 6 款双向主从站仿真器与 CLI 引擎。无需安装任何底层驱动，支持 Windows、macOS、Linux (x64 / ARM64)。

### 亮点
1. **纯 Dart 自研协议栈**：无 C++ 原生依赖与 WinPcap 驱动束缚，解压即跑；
2. **Material 3 工业质感 UI**：无缝无边框窗口、高对比度深色模式、17 种语言运行时无缝切换；
3. **动态波形仿真引擎**：正弦、三角、随机游走等多种数学曲线发生器，免硬件调试；
4. **CI/CD 全自动化跨平台构建**：GitHub Actions 原生输出 Windows (.exe/.zip)、macOS (.dmg) 与 Linux (.deb/.tar.gz) 发布产物。

### 截图展示
![Dashboard](https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec104_server.png)
"""

def copy_to_clipboard(text: str):
    try:
        proc = subprocess.Popen(["xclip", "-selection", "clipboard"], stdin=subprocess.PIPE)
        proc.communicate(text.encode("utf-8"))
        print("✅ 已成功将文案写入系统剪贴板 (Ctrl+V 可直接粘贴)！")
        return True
    except Exception as e:
        print(f"⚠️ 写入剪贴板失败: {e}")
        return False

def open_url(url: str):
    print(f"🌐 正在打开浏览器网页: {url[:80]}...")
    subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def submit_github_issue(token: str, repo: str, title: str, body: str):
    import urllib.request
    url = f"https://api.github.com/repos/{repo}/issues"
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "IndustrialProtocolSuite-Promoter"
    }
    data = json.dumps({"title": title, "body": body}).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            print(f"🎉 成功向 {repo} 提交 Issue: {result.get('html_url')}")
            return result.get('html_url')
    except Exception as e:
        print(f"❌ API 提交失败: {e}")
        return None

def main():
    print("=" * 60)
    print(" 🚀 Industrial Protocol Suite (IPS) 推广助手")
    print("=" * 60)
    print("1. [一键打开] 阮一峰《科技爱好者周刊》自荐页面 (预填好标题与内容)")
    print("2. [一键打开] HelloGitHub 开源自荐页面 (预填好标题与内容)")
    print("3. [一键复制] 复制知乎 / 掘金 / CSDN 深度技术长文到剪贴板并打开编辑器")
    print("4. [一键复制] 复制 V2EX 推广文案到剪贴板并打开 V2EX 发帖页面")
    print("5. [一键复制] 复制 Reddit (r/PLC) 英文推广贴并打开发帖页面")
    print("6. [API 发稿] 使用 GitHub Token 自动通过 API 提交到阮一峰周刊 & HelloGitHub")
    print("=" * 60)

    if len(sys.argv) > 1:
        choice = sys.argv[1]
    else:
        choice = "1"

    if choice == "1":
        query = urllib.parse.urlencode({"title": RUANYF_TITLE, "body": RUANYF_BODY})
        target_url = f"https://github.com/ruanyf/weekly/issues/new?{query}"
        copy_to_clipboard(RUANYF_BODY)
        open_url(target_url)
    elif choice == "2":
        params = {
            "template": "submit-cn.yaml",
            "project_url": REPO_URL,
            "category": "其它",
            "project_title": "基于 Flutter & 纯 Dart 的跨平台工业电力规约仿真套件",
            "project_description": "基于 Flutter & 纯 Dart 自研的现代化跨平台工业电力自动化规约仿真平台。完整覆盖 IEC 60870-5-104、IEC 61850 MMS/GOOSE 及 Modbus TCP/RTU，包含 6 款全功能客户端与服务端桌面软件及 CLI 引擎。零驱动依赖，解压即用。",
            "project_highlights": "1. 100% 纯 Dart 协议栈：无 C++ 原生库与 WinPcap 驱动束缚，真正零依赖；\n2. Material 3 工业无边框 UI：沉浸式标题栏、高对比度深色模式、支持 17 种语言切换（含 RTL）；\n3. 动态波形数学仿真：内置正弦波、方波、随机游走等 6 种曲线发生器，免硬件模拟遥测；\n4. 自动化 CI/CD 构建：GitHub Actions 原生输出 Windows (.exe/.zip)、macOS (.dmg) 与 Linux (.deb/.tar.gz)。",
            "project_screenshot": "https://raw.githubusercontent.com/orglibs/industrial-protocol-suite/main/docs/images/screenshot_iec104_server.png"
        }
        target_url = f"https://github.com/521xueweihan/HelloGitHub/issues/new?{urllib.parse.urlencode(params)}"
        copy_to_clipboard(HELLOGITHUB_BODY)
        open_url(target_url)
    elif choice == "3":
        article_path = os.path.join(os.path.dirname(__file__), "..", "docs", "PROMOTION_ARTICLE_ZH.md")
        with open(article_path, "r", encoding="utf-8") as f:
            article = f.read()
        copy_to_clipboard(article)
        open_url("https://juejin.cn/editor/drafts/new")
        open_url("https://zhuanlan.zhihu.com/write")
    elif choice == "4":
        v2ex_text = f"""各位 V 友，

在工业自动化和电力 SCADA 领域，大家调试规约时往往还在用着十几年前用 MFC/Delphi 写的闭源商业软件，不仅 UI 粗糙，还经常需要装各种底层抓包驱动，跨平台调试更是奢望。

最近我们团队用 Flutter & 纯 Dart 自主研发并开源了一套跨平台工业规约仿真平台 —— **Industrial Protocol Suite (IPS)**：
* GitHub: {REPO_URL}
* 官网与全平台下载: {SITE_URL}

核心特点：
1. **6 合 1 全体系双向仿真**：
   - IEC 60870-5-104 服务端 (RTU) & 客户端 (调度中心)
   - IEC 61850 MMS & GOOSE 服务端 & 在线自发现监控客户端
   - Modbus TCP/RTU/UDP 从站 (MSE) & 主站 (MME)
2. **100% 纯 Dart 协议栈**：无任何 C++ 原生动态库依赖，真正零驱动开箱即用。
3. **Material 3 工业桌面质感**：无缝无边框窗口、深浅色模式持久化、支持 17 种国际化语言（含阿拉伯语 RTL）。
4. **内置数学波形仿真**：正弦、方波、随机游走等 6 种动态曲线，免接硬件即可模拟真实遥测信号。

安装包通过 GitHub Actions 原生打包（Windows .exe 向导/免安装版、macOS .dmg、Linux .deb/tar.gz）。
欢迎在电力自动化、物联网、工业控制领域的 V 友们上手体验，求轻拍和 Star 支持！"""
        copy_to_clipboard(v2ex_text)
        open_url("https://v2ex.com/new/create")
    elif choice == "5":
        reddit_text = f"""Hi everyone,

We've recently open-sourced **Industrial Protocol Suite (IPS)**, an all-in-one industrial and power automation protocol simulator built purely with Flutter and Dart:

- GitHub: {REPO_URL}
- Website & Downloads: {SITE_URL}

Key Highlights:
- **Comprehensive 6-in-1 Subsystems**:
  - IEC 60870-5-104 Server (RTU) & Client (Master)
  - IEC 61850 Server (MMS / GOOSE / SCL) & Client (Online dynamic discovery)
  - Modbus Slave (MSE) & Master (MME) for TCP / POSIX Serial RTU / UDP
- **Zero Native Dependencies**: Pure Dart protocol stack. No WinPcap, Npcap, or external C++ drivers required.
- **Waveform Math Engine**: Generates real-time sine, square, triangle, and noise waveforms for telemetry simulation without physical hardware.
- **Cross-Platform**: Ready-to-use binaries for Windows (.exe / .zip), macOS (.dmg), and Linux (.deb / .tar.gz).

Feedback and contributions are warmly welcome!"""
        copy_to_clipboard(reddit_text)
        open_url("https://www.reddit.com/r/PLC/submit")
    elif choice == "6":
        token = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("GITHUB_TOKEN")
        if not token:
            print("❌ 请提供 GITHUB_TOKEN，例如: python3 scripts/promote.py 6 <YOUR_GITHUB_TOKEN>")
            sys.exit(1)
        submit_github_issue(token, "ruanyf/weekly", RUANYF_TITLE, RUANYF_BODY)
        submit_github_issue(token, "521xueweihan/HelloGitHub", HELLOGITHUB_TITLE, HELLOGITHUB_BODY)

if __name__ == "__main__":
    main()
