# AGENTS.md — UlanziDialLite

给接手这个仓库的 AI agent 的规则。

## 这个项目是什么

Ulanzi D100H 旋钮控制器的原生轻量替代品。目标：不用 Ulanzi Studio（1 GB / ~500 MB 内存），
只做用户要的那一层——**12 个可控槽位的自定义绑定**。

## 硬规则

1. **绑定关系不得写死在代码里。** 所有槽位动作来自 `config.json`，由设置界面写入；
   代码里只允许存在"首次运行的默认值"（当前为旋钮顺/逆时针=音量、旋钮按下=静音）。
2. **不改系统、不改用户其他数据。** 只读写：
   - `~/Library/Application Support/UlanziDialLite/config.json`
   - `~/Library/Logs/UlanziDialLite.log`
3. **不删除文件。** 构建产物直接覆盖；需要清理时移入废纸篓并说明。
4. **不替用户启动 / 退出 Ulanzi Studio。** 两者同时运行会争抢设备，需要时先问。
5. 打包与签名只做本机 ad-hoc（`codesign -s -`），不做公证、不分发。

## 协议要点（改动前必读）

- service `00001971-…`，write `0000fd01-…`（withoutResponse），notify `0000fd00-…`
- 20 字节包，原始 TEA 32 轮，**只加密前 16 字节**，后 4 字节保持明文
- 心跳：明文 `06 01 23 00 01` + 15 个 0，每秒一次，否则约 3 秒后设备回落到 HID 模式
- 事件：`8b 10 <ID> <state>`；ID 表见 `Protocol.swift` 的 `Control`
- 旋钮点击是松手时补发的 down/up 对，只认 down

## 验收方式

1. `./scripts/build.sh` 必须零警告失败
2. 启动后日志里必须有 `selftest overall: PASS`（4 组抓包向量双向比对）
3. 真机验收：连上设备 → 在设置界面录制快捷键 → 按键/转旋钮 → 目标应用确实收到输入
4. 内存基线用 `ps -o rss` 实测，不引用口头数字
