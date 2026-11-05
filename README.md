# UlanziDialLite

Ulanzi D100H「Dial」旋钮控制器的轻量原生替代方案：不装 Ulanzi Studio（1.0 GB 包体 / ~500 MB 常驻内存），
只保留真正用得到的那一层——**给 12 个可控槽位各自绑定一个动作**。

## 现状

- [x] BLE 连接（service `0x1971`，write `fd01`，notify `fd00`）+ 每秒心跳维持在线上模式
- [x] TEA 解密与事件解析（7 键 + 旋钮按下 + 顺/逆时针 + 按住旋钮顺/逆时针，共 12 槽位）
- [x] 动作执行：任意快捷键（CGEvent）/ 媒体键（音量、静音、播放暂停、上/下一首）
- [x] 菜单栏 App + 图形设置界面，槽位动作由用户自己设，不写死在代码里
- [x] 配置持久化到 `~/Library/Application Support/UlanziDialLite/config.json`
- [ ] 按前台应用自动切换配置（未做，当前为单一套映射）
- [ ] 触感强度 / 休眠时间写入（协议已知，未接线）
- [ ] 开机自启（默认不做，按偏好手动启动）

## 结构

```
Sources/UlanziDialLite/
  main.swift          入口（LSUIElement 菜单栏）
  AppDelegate.swift   状态栏菜单、设置窗口
  Protocol.swift      日志、TEA、BLE 连接与事件解码
  Bindings.swift      Control / Action 模型与配置读写
  Actions.swift       快捷键与媒体键注入、辅助功能权限
  SettingsView.swift  设置界面（SwiftUI）
scripts/build.sh      构建 .app
```

## 构建与运行

```bash
./scripts/build.sh
open build/UlanziDialLite.app
```

首次运行需要在「系统设置 → 隐私与安全性」里授予：
- **蓝牙**：读取设备事件
- **辅助功能**：模拟快捷键

## 协议依据

设备 BLE 协议由社区逆向并逐项验证（firmware 1.3.8.1）：

- 包格式：20 字节，原始 TEA 32 轮，仅加密前 16 字节，密钥硬编码在厂商 App 内
- 事件：`8b 10 <ID> <STATE>`，STATE `01` = 按下/一格，`00` = 抬起
- 在线模式：每秒发送 `06 01 23 00 01` 心跳；停发约 3 秒后设备回落到自带 HID 行为（音量/媒体键）
- 旋钮点击是**松手时**补发的 down/up 一对事件，不能当作按住状态

参考：
- https://github.com/kriomant/ulanzi-d100h （Rust/Python 驱动 + PROTOCOL.md）
- https://github.com/brendanwelsh/ulanzi-d100h-homebrew （HID 层与 Studio 内部结构笔记）
