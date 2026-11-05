# UlanziDial Native

> **非官方项目。** 与 Ulanzi（深圳优篮子科技）没有任何关系，不是官方软件。本项目是个人自用的轻量替代品，
> 不使用其商标做宣传，也不包含官方软件的任何二进制、图标或插件资源。
>
> **Unofficial project.** Not affiliated with Ulanzi in any way. A personal, lightweight replacement,
> built for my own use. No official binaries, icons, or plugin assets are included.

给 Ulanzi D100H「Dial」旋钮控制器用的原生 macOS 客户端：不装 1.0 GB 的 Ulanzi Studio，只保留真正用得到的那一层——
**给 12 个可控槽位各自绑定一个动作**。

A native macOS client for the Ulanzi D100H "Dial" controller. It replaces the 1.0 GB Ulanzi Studio
with just the part that matters: **binding an action to each of the 12 controllable slots**.

---

## 中文

### 它是什么

Ulanzi D100H 是「3 个顶键 + 4 个侧键 + 一个旋钮」的剪辑控制器。官方软件 Ulanzi Studio 为了插件生态
背了内嵌 Chromium、Node 运行时和整套 Qt 模块，包体 1.0 GB、常驻内存约 500 MB。

本项目用系统原生框架重写了最核心的一层：

- **包体约 1 MB，常驻内存约 37 MB**
- Swift + SwiftUI + AppKit + CoreBluetooth + CGEvent + ServiceManagement，**零第三方依赖**
- 界面使用 macOS 26 的原生液态玻璃 API（`glassEffect`）；更早的系统自动退回材质效果

### 功能

- **12 个槽位**：顶部三键、四个侧键、旋钮按下、旋钮顺/逆时针、按住旋钮顺/逆时针
- **9 类动作**：键盘快捷键（任意组合，含被系统预留的 ⌥⌘Tab）、系统媒体键、输入文字、打开 App、
  打开网址或文件、运行 shell 命令、系统操作（锁屏/睡眠/关显示器/屏保/三种截屏/调度中心/启动台/深色切换）、多项操作、无
- **多项操作**：按顺序执行多步动作，每步可设等待毫秒数
- **多套配置**：可建多套映射，并给指定 App 绑定规则，切到那个 App 自动套用
- **完全隐形**：不占 Dock、不占菜单栏，`⌥⌘D`（可自定义）呼出设置窗口
- **开机自启**：Apple 官方 `SMAppService`
- **电量显示**：走标准 GATT 电量特征（0x2A19），不依赖厂商不定期上报

### 和官方软件的差别

| | Ulanzi Studio | UlanziDial Native |
|---|---|---|
| 包体 | 1.0 GB | 约 1 MB |
| 常驻内存 | 约 500 MB | 约 37 MB |
| 运行时 | 内嵌 Chromium + Node + Qt | 系统框架 |
| 界面 | 深色工程风 | 原生 macOS（液态玻璃） |
| 插件市场 / OBS / 灯控 / TC002 | 有 | 没有（本项目只做核心绑定） |

### 构建

```bash
./scripts/build.sh            # 构建（有签名证书就签名，没有就 ad-hoc）
./scripts/install-local.sh    # 构建 + 签名 + 装到 /Applications（旧版移入废纸篓）
./scripts/release.sh          # 构建 + Developer ID 签名 + 公证 + staple
```

要求：macOS 13 及以上（液态玻璃效果需要 macOS 26 及以上），Xcode 命令行工具。

首次运行需要授予两项权限：

- **蓝牙**：连接设备、读取按键与电量
- **辅助功能**：模拟键盘快捷键

### 协议依据

设备 BLE 协议由社区逆向并逐项验证（测试固件 1.3.8.1），本项目在其基础上重写：

- 厂商服务 `0x1971`，写特征 `fd01`，通知特征 `fd00`
- 20 字节包，原始 TEA（32 轮），只加密前 16 字节
- 在线模式：每秒发送 `06 01 23 00 01` 心跳；停发约 3 秒后设备回落到自带 HID 行为
- 事件：`8b 10 <ID> <STATE>`，`01` = 按下 / 一格，`00` = 抬起

参考项目：

- <https://github.com/kriomant/ulanzi-d100h> — Rust/Python 驱动与 `PROTOCOL.md`
- <https://github.com/brendanwelsh/ulanzi-d100h-homebrew> — HID 层与 Studio 内部结构笔记

### 已知限制

- 只在 D100H / 固件 1.3.8.1 + macOS 26 上验证过
- 不能和 Ulanzi Studio 同时运行（会争抢同一个 BLE 设备）
- 没有实现 OBS、灯光控制、TC002 像素时钟等官方插件
- 设备断电或超出范围后，重连需要几秒

---

## English

### What it is

The Ulanzi D100H is a "3 top keys + 4 side keys + one dial" editing controller. The official
Ulanzi Studio ships an embedded Chromium, a Node runtime and a full Qt stack to support its plugin
ecosystem: 1.0 GB on disk, roughly 500 MB resident.

This project rewrites only the layer that matters, using Apple's own frameworks:

- **~1 MB app bundle, ~37 MB resident memory**
- Swift + SwiftUI + AppKit + CoreBluetooth + CGEvent + ServiceManagement, **zero third-party dependencies**
- Uses the native Liquid Glass API on macOS 26 (`glassEffect`), falling back to materials on older systems

### Features

- **12 slots**: three top keys, four side keys, dial press, dial rotate CW/CCW, and press-and-rotate CW/CCW
- **9 action kinds**: keyboard shortcut (any combination, including system-reserved ones like ⌥⌘Tab),
  media keys, type text, open an app, open a URL or file, run a shell command, system actions
  (lock, sleep, display sleep, screensaver, three screenshot modes, Mission Control, Launchpad, dark mode),
  multi-step sequences, and none
- **Multi-step sequences**: run actions in order, with a configurable delay after each step
- **Multiple profiles**: keep several mapping sets and bind them to specific apps; the right profile
  is applied automatically when you switch apps
- **Completely invisible**: no Dock icon, no menu bar item; `⌥⌘D` (configurable) opens settings
- **Launch at login** via Apple's `SMAppService`
- **Battery level** read from the standard GATT characteristic (0x2A19) instead of vendor pushes

### How it differs from the official app

| | Ulanzi Studio | UlanziDial Native |
|---|---|---|
| Bundle size | 1.0 GB | ~1 MB |
| Resident memory | ~500 MB | ~37 MB |
| Runtime | embedded Chromium + Node + Qt | system frameworks |
| UI | dark engineering style | native macOS (Liquid Glass) |
| Plugin market / OBS / lights / TC002 | yes | no (this project only does core binding) |

### Building

```bash
./scripts/build.sh            # build (signs if a certificate is available, otherwise ad-hoc)
./scripts/install-local.sh    # build + sign + install to /Applications (old copy goes to Trash)
./scripts/release.sh          # build + Developer ID sign + notarize + staple
```

Requires macOS 13+ (Liquid Glass needs macOS 26+), Xcode command line tools.

Two permissions are required on first launch:

- **Bluetooth** — to talk to the device and read keys and battery
- **Accessibility** — to synthesize keyboard shortcuts

### Protocol notes

The BLE protocol was reverse-engineered and verified by the community (tested on firmware 1.3.8.1);
this project is a clean reimplementation on top of those findings:

- Vendor service `0x1971`, write characteristic `fd01`, notify characteristic `fd00`
- 20-byte packets, original TEA (32 rounds), only the first 16 bytes encrypted
- Online mode: a `06 01 23 00 01` heartbeat every second; about 3 seconds after heartbeats stop the
  device falls back to its built-in HID behaviour
- Events: `8b 10 <ID> <STATE>`, `01` = press / one detent, `00` = release

References:

- <https://github.com/kriomant/ulanzi-d100h> — Rust/Python driver and `PROTOCOL.md`
- <https://github.com/brendanwelsh/ulanzi-d100h-homebrew> — HID layer and Studio internals notes

### Known limitations

- Verified only on the D100H, firmware 1.3.8.1, macOS 26
- Cannot run at the same time as Ulanzi Studio (both compete for the same BLE device)
- No OBS, light control, or TC002 pixel clock integrations
- Reconnection after the device powers off takes a few seconds

---

## License

MIT (see `LICENSE`). The name "Ulanzi" is a trademark of Shenzhen Ulanzi Technology Co., Ltd.,
used here only to describe what hardware this software talks to.
