import Foundation

// MARK: - 路径

let supportDir = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/UlanziDialNative", isDirectory: true)
let configURL = supportDir.appendingPathComponent("config.json")

// MARK: - 槽位别名

let slotAliases: [String: Control] = [
    // 顶部三键
    "topleft": .topLeft, "top-left": .topLeft, "tl": .topLeft, "左上": .topLeft, "顶部左键": .topLeft,
    "topmiddle": .topMiddle, "top-middle": .topMiddle, "tm": .topMiddle, "中上": .topMiddle, "顶部中键": .topMiddle,
    "topright": .topRight, "top-right": .topRight, "tr": .topRight, "右上": .topRight, "顶部右键": .topRight,
    // 四个侧键
    "sideupperleft": .sideUpperLeft, "sul": .sideUpperLeft, "左侧上键": .sideUpperLeft, "左上侧": .sideUpperLeft,
    "sideupperright": .sideUpperRight, "sur": .sideUpperRight, "右侧上键": .sideUpperRight, "右上侧": .sideUpperRight,
    "sidelowerleft": .sideLowerLeft, "sll": .sideLowerLeft, "左侧下键": .sideLowerLeft, "左下侧": .sideLowerLeft,
    "sidelowerright": .sideLowerRight, "slr": .sideLowerRight, "右侧下键": .sideLowerRight, "右下侧": .sideLowerRight,
    // 旋钮
    "knob": .knobClick, "knobclick": .knobClick, "press": .knobClick, "按下旋钮": .knobClick, "旋钮按下": .knobClick,
    "cw": .rotateCW, "rotatecw": .rotateCW, "顺时针": .rotateCW, "旋钮顺时针": .rotateCW,
    "ccw": .rotateCCW, "rotateccw": .rotateCCW, "逆时针": .rotateCCW, "旋钮逆时针": .rotateCCW,
    "holdcw": .knobHoldCW, "按住顺时针": .knobHoldCW,
    "holdccw": .knobHoldCCW, "按住逆时针": .knobHoldCCW,
]

func parseSlot(_ raw: String) -> Control? {
    let key = raw.lowercased().trimmingCharacters(in: .whitespaces)
    if let byName = slotAliases[key] { return byName }
    if let value = UInt8(key, radix: 16) { return Control.from(id: value) }
    return nil
}

// MARK: - 快捷键解析

let keyTable: [String: (UInt16, String)] = [
    "a": (0, "A"), "s": (1, "S"), "d": (2, "D"), "f": (3, "F"), "h": (4, "H"), "g": (5, "G"),
    "z": (6, "Z"), "x": (7, "X"), "c": (8, "C"), "v": (9, "V"), "b": (11, "B"), "q": (12, "Q"),
    "w": (13, "W"), "e": (14, "E"), "r": (15, "R"), "y": (16, "Y"), "t": (17, "T"),
    "1": (18, "1"), "2": (19, "2"), "3": (20, "3"), "4": (21, "4"), "6": (22, "6"), "5": (23, "5"),
    "=": (24, "="), "9": (25, "9"), "7": (26, "7"), "-": (27, "-"), "8": (28, "8"), "0": (29, "0"),
    "]": (30, "]"), "o": (31, "O"), "u": (32, "U"), "[": (33, "["), "i": (34, "I"), "p": (35, "P"),
    "return": (36, "↩"), "enter": (36, "↩"), "l": (37, "L"), "j": (38, "J"), "'": (39, "'"),
    "k": (40, "K"), ";": (41, ";"), "\\": (42, "\\"), ",": (43, ","), "/": (44, "/"), "n": (45, "N"),
    "m": (46, "M"), ".": (47, "."), "tab": (48, "⇥"), "space": (49, "Space"), "`": (50, "`"),
    "delete": (51, "⌫"), "backspace": (51, "⌫"), "escape": (53, "Esc"), "esc": (53, "Esc"),
    "f1": (122, "F1"), "f2": (120, "F2"), "f3": (99, "F3"), "f4": (118, "F4"), "f5": (96, "F5"),
    "f6": (97, "F6"), "f7": (98, "F7"), "f8": (100, "F8"), "f9": (101, "F9"), "f10": (109, "F10"),
    "f11": (103, "F11"), "f12": (111, "F12"),
    "left": (123, "←"), "right": (124, "→"), "down": (125, "↓"), "up": (126, "↑"),
    "home": (115, "Home"), "end": (119, "End"), "pageup": (116, "⇞"), "pagedown": (121, "⇟"),
    "forwarddelete": (117, "⌦"),
]

let modifierTable: [String: (UInt, String)] = [
    "ctrl": (1 << 18, "⌃"), "control": (1 << 18, "⌃"), "⌃": (1 << 18, "⌃"),
    "opt": (1 << 19, "⌥"), "option": (1 << 19, "⌥"), "alt": (1 << 19, "⌥"), "⌥": (1 << 19, "⌥"),
    "shift": (1 << 17, "⇧"), "⇧": (1 << 17, "⇧"),
    "cmd": (1 << 20, "⌘"), "command": (1 << 20, "⌘"), "⌘": (1 << 20, "⌘"),
]

struct Combo {
    var keyCode: UInt16
    var modifiers: UInt
    var label: String
}

func parseCombo(_ raw: String) -> Combo? {
    let parts = raw.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces).lowercased() }
    guard let last = parts.last, let (code, name) = keyTable[last] else { return nil }
    var mods: UInt = 0
    var symbols = ["", "", "", ""]   // ⌃ ⌥ ⇧ ⌘
    for part in parts.dropLast() {
        guard let (flag, symbol) = modifierTable[part] else { return nil }
        mods |= flag
        switch symbol {
        case "⌃": symbols[0] = symbol
        case "⌥": symbols[1] = symbol
        case "⇧": symbols[2] = symbol
        case "⌘": symbols[3] = symbol
        default: break
        }
    }
    return Combo(keyCode: code, modifiers: mods, label: symbols.joined() + name)
}

// MARK: - 读写配置

func defaultBindings() -> [String: Action] {
    [
        "0a": Action(kind: .media, media: MediaKey.volumeUp.rawValue),
        "09": Action(kind: .media, media: MediaKey.volumeDown.rawValue),
        "07": Action(kind: .media, media: MediaKey.mute.rawValue),
    ]
}

func loadConfig() -> ConfigFile {
    if let data = try? Data(contentsOf: configURL),
       let config = try? JSONDecoder().decode(ConfigFile.self, from: data) {
        return config
    }
    return ConfigFile(
        version: 3,
        activeProfile: "默认",
        profiles: ["默认": defaultBindings()],
        appRules: [:],
        doubleBindings: [:],
        longBindings: [:]
    )
}

func saveConfig(_ config: ConfigFile) {
    try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    guard let data = try? encoder.encode(config) else {
        fail("配置编码失败")
    }
    // 原子写入：CLI 写坏时不会留下半个文件
    let tmp = supportDir.appendingPathComponent("config.cli-tmp.json")
    do {
        try data.write(to: tmp)
        if FileManager.default.fileExists(atPath: configURL.path) {
            _ = try FileManager.default.replaceItemAt(configURL, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: configURL)
        }
    } catch {
        fail("写入配置失败：\(error.localizedDescription)")
    }
}

// MARK: - 输出

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("✗ \(message)\n".utf8))
    exit(1)
}

func profileName(_ config: ConfigFile) -> String { config.activeProfile ?? "默认" }

func actionFor(_ config: ConfigFile, _ slot: String, _ gesture: ClickGesture) -> Action {
    let profile = profileName(config)
    let map: [String: Action]
    switch gesture {
    case .single: map = config.profiles[profile] ?? [:]
    case .double: map = config.doubleBindings?[profile] ?? [:]
    case .long:   map = config.longBindings?[profile] ?? [:]
    }
    return map[slot] ?? .empty
}

func setAction(_ config: inout ConfigFile, _ slot: String, _ gesture: ClickGesture, _ action: Action) {
    let profile = profileName(config)
    switch gesture {
    case .single:
        var map = config.profiles[profile] ?? [:]
        map[slot] = action
        config.profiles[profile] = map
    case .double:
        var all = config.doubleBindings ?? [:]
        var map = all[profile] ?? [:]
        map[slot] = action
        all[profile] = map
        config.doubleBindings = all
    case .long:
        var all = config.longBindings ?? [:]
        var map = all[profile] ?? [:]
        map[slot] = action
        all[profile] = map
        config.longBindings = all
    }
}

func pad(_ text: String, _ width: Int) -> String {
    let count = text.count
    return count >= width ? text : text + String(repeating: " ", count: width - count)
}

/// 把「类型 + 参数」翻成 Action；失败直接退出
func buildAction(type rawType: String, value: String) -> Action {
    let type = rawType.lowercased()
    switch type {
    case "key", "hotkey":
        guard let combo = parseCombo(value) else { fail("快捷键写法看不懂：\(value)\n例：cmd+shift+4 / opt+tab / f5 / space") }
        return Action(kind: .key, keyCode: combo.keyCode, modifiers: combo.modifiers, keyLabel: combo.label)
    case "media":
        let key = value.lowercased()
        guard let media = MediaKey.allCases.first(where: { $0.rawValue.lowercased() == key || $0.name.lowercased() == key }) else {
            fail("不认识的媒体键：\(value)\n可选：\(MediaKey.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }
        return Action(kind: .media, media: media.rawValue)
    case "app":
        guard !value.isEmpty else { fail("用法：app <路径.app>") }
        return Action(kind: .app, path: value)
    case "url":
        guard !value.isEmpty else { fail("用法：url <网址或文件路径>") }
        return Action(kind: .url, url: value)
    case "text":
        guard !value.isEmpty else { fail("用法：text <要输入的文字>") }
        return Action(kind: .text, text: value)
    case "shell":
        guard !value.isEmpty else { fail("用法：shell <命令>") }
        return Action(kind: .shell, command: value)
    case "system":
        guard let system = SystemAction(rawValue: value) ?? SystemAction.allCases.first(where: { $0.name == value }) else {
            fail("不认识的系统操作：\(value)\n可选：\(SystemAction.allCases.map { $0.rawValue }.joined(separator: ", "))")
        }
        return Action(kind: .system, system: system.rawValue)
    case "sequence":
        return Action(kind: .sequence, steps: [])
    default:
        fail("未知类型：\(rawType)\n类型：key media app url text shell system sequence")
    }
}

/// 修饰键写法：opt / ⌥ / cmd+shift 等
func modifierLabel(_ mask: UInt) -> String {
    var out = ""
    if mask & (1 << 18) != 0 { out += "⌃" }
    if mask & (1 << 19) != 0 { out += "⌥" }
    if mask & (1 << 17) != 0 { out += "⇧" }
    if mask & (1 << 20) != 0 { out += "⌘" }
    return out
}

func parseModifierMask(_ raw: String) -> UInt {
    let parts = raw.replacingOccurrences(of: "+", with: " ").split(separator: " ").map { String($0).lowercased() }
    var mask: UInt = 0
    for part in parts {
        guard let (flag, _) = modifierTable[part] else { fail("不认识的修饰键：\(part)\n可选：ctrl opt shift cmd") }
        mask |= flag
    }
    guard mask != 0 else { fail("修饰键不能为空") }
    return mask
}

// MARK: - 命令

var args = Array(CommandLine.arguments.dropFirst())
var jsonOutput = false
var gesture: ClickGesture = .single
var profileOverride: String?

var filtered: [String] = []
for arg in args {
    switch arg {
    case "--json": jsonOutput = true
    case "--double": gesture = .double
    case "--long": gesture = .long
    default: filtered.append(arg)
    }
}
args = filtered

if let index = args.firstIndex(of: "--profile"), index + 1 < args.count {
    profileOverride = args[index + 1]
    args.removeSubrange(index...(index + 1))
}

let command = args.first ?? "help"

switch command {
case "list", "ls":
    var config = loadConfig()
    if let p = profileOverride { config.activeProfile = p }
    let profile = profileName(config)
    print("配置：\(profile)")
    print(pad("槽位", 14) + pad("单击", 20) + pad("双击", 20) + "长按")
    for control in Control.ordered {
        let slot = String(format: "%02x", control.rawValue)
        let single = actionFor(config, slot, .single).describe
        let double = actionFor(config, slot, .double).describe
        let long = actionFor(config, slot, .long).describe
        print(pad(control.name, 14) + pad(single, 20) + pad(double, 20) + long)
    }

case "get":
    guard args.count >= 2, let control = parseSlot(args[1]) else { fail("用法：ulanzidial get <槽位>") }
    var config = loadConfig()
    if let p = profileOverride { config.activeProfile = p }
    let slot = String(format: "%02x", control.rawValue)
    let action = actionFor(config, slot, gesture)
    if jsonOutput {
        print("{\"slot\":\"\(slot)\",\"name\":\"\(control.name)\",\"gesture\":\"\(gesture.rawValue)\",\"action\":\"\(action.describe)\"}")
    } else {
        print("\(control.name) [\(gesture.name)] → \(action.describe)")
    }

case "set":
    guard args.count >= 3, let control = parseSlot(args[1]) else {
        fail("用法：ulanzidial set <槽位> <类型> <参数>\n类型：key media app url text shell system sequence")
    }
    let slot = String(format: "%02x", control.rawValue)
    let type = args[2].lowercased()
    let value = args.dropFirst(3).joined(separator: " ")
    let action = buildAction(type: type, value: value)

    var config = loadConfig()
    if let p = profileOverride {
        config.activeProfile = p
        if config.profiles[p] == nil { config.profiles[p] = [:] }
    }
    setAction(&config, slot, gesture, action)
    saveConfig(config)
    logLine("cli set \(control.name)[\(gesture.name)] -> \(action.describe)")
    print("✓ \(control.name) [\(gesture.name)] → \(action.describe)")

case "clear":
    guard args.count >= 2, let control = parseSlot(args[1]) else { fail("用法：ulanzidial clear <槽位>") }
    var config = loadConfig()
    setAction(&config, String(format: "%02x", control.rawValue), gesture, .empty)
    saveConfig(config)
    logLine("cli clear \(control.name)[\(gesture.name)]")
    print("✓ 已清除 \(control.name) [\(gesture.name)]")

case "chord":
    guard args.count >= 2 else { fail("用法：ulanzidial chord <add|list|clear> …") }
    var config = loadConfig()
    switch args[1] {
    case "add":
        guard args.count >= 5 else { fail("用法：ulanzidial chord add <槽位+槽位> <类型> <参数>\n例：ulanzidial chord add 顶部左键+右侧下键 key cmd+shift+5") }
        let keys = args[2].split(separator: "+").compactMap { parseSlot(String($0)) }
        guard keys.count >= 2 else { fail("至少两个槽位，例：01+08 或 顶部左键+右侧下键") }
        let action = buildAction(type: args[3], value: args.dropFirst(4).joined(separator: " "))
        var chords = config.chords ?? []
        chords.append(ChordSpec(keys: keys.map { String(format: "%02x", $0.rawValue) }, action: action))
        config.chords = chords
        saveConfig(config)
        print("✓ 组合 \(keys.map { $0.name }.joined(separator: " + ")) → \(action.describe)")
    case "list":
        let chords = config.chords ?? []
        if chords.isEmpty { print("（没有组合）") }
        for spec in chords { print("• \(spec.describe) → \(spec.action.describe)") }
    case "clear":
        config.chords = []
        saveConfig(config)
        print("✓ 已清空全部组合")
    default:
        fail("用法：ulanzidial chord <add|list|clear> …")
    }

case "layer":
    guard args.count >= 2 else { fail("用法：ulanzidial layer <add|list|clear> …") }
    var config = loadConfig()
    switch args[1] {
    case "add":
        guard args.count >= 6 else { fail("用法：ulanzidial layer add <按住键> <目标槽位> <类型> <参数>\n例：ulanzidial layer add 右侧上键 顶部左键 media mute") }
        guard let hold = parseSlot(args[2]), let target = parseSlot(args[3]) else { fail("槽位认不出来") }
        let action = buildAction(type: args[4], value: args.dropFirst(5).joined(separator: " "))
        var layers = config.layers ?? []
        let holdID = String(format: "%02x", hold.rawValue)
        let targetID = String(format: "%02x", target.rawValue)
        if let index = layers.firstIndex(where: { $0.hold == holdID }) {
            layers[index].bindings[targetID] = action
        } else {
            layers.append(LayerSpec(hold: holdID, bindings: [targetID: action]))
        }
        config.layers = layers
        saveConfig(config)
        print("✓ 按住 \(hold.name) 时 \(target.name) → \(action.describe)")
    case "list":
        let layers = config.layers ?? []
        if layers.isEmpty { print("（没有功能层）") }
        for spec in layers {
            print("• 按住 \(spec.holdName) 时：")
            for (slot, action) in spec.bindings.sorted(by: { $0.key < $1.key }) {
                let name = UInt8(slot, radix: 16).flatMap { Control.from(id: $0) }?.name ?? slot
                print("    \(name) → \(action.describe)")
            }
        }
    case "clear":
        config.layers = []
        saveConfig(config)
        print("✓ 已清空全部功能层")
    default:
        fail("用法：ulanzidial layer <add|list|clear> …")
    }

case "mod":
    guard args.count >= 2 else { fail("用法：ulanzidial mod <add|list|clear> …") }
    var config = loadConfig()
    switch args[1] {
    case "add":
        guard args.count >= 6 else { fail("用法：ulanzidial mod add <修饰键> <槽位> <类型> <参数>\n例：ulanzidial mod add opt 旋钮顺时针 media brightnessUp") }
        let mask = parseModifierMask(args[2])
        guard let control = parseSlot(args[3]) else { fail("槽位认不出来：\(args[3])") }
        let action = buildAction(type: args[4], value: args.dropFirst(5).joined(separator: " "))
        var specs = config.modifierActions ?? []
        specs.append(ModifierSpec(mask: mask, control: String(format: "%02x", control.rawValue), action: action))
        config.modifierActions = specs
        saveConfig(config)
        print("✓ \(modifierLabel(mask))+\(control.name) → \(action.describe)")
    case "list":
        let specs = config.modifierActions ?? []
        if specs.isEmpty { print("（没有修饰键动作）") }
        for spec in specs {
            let name = UInt8(spec.control, radix: 16).flatMap { Control.from(id: $0) }?.name ?? spec.control
            print("• \(spec.maskLabel)+\(name) → \(spec.action.describe)")
        }
    case "clear":
        config.modifierActions = []
        saveConfig(config)
        print("✓ 已清空全部修饰键动作")
    default:
        fail("用法：ulanzidial mod <add|list|clear> …")
    }

case "profiles":
    let config = loadConfig()
    for name in config.profiles.keys.sorted() {
        let mark = name == profileName(config) ? "*" : " "
        print("\(mark) \(name)（\(config.profiles[name]?.count ?? 0) 项）")
    }

case "use":
    guard args.count >= 2 else { fail("用法：ulanzidial use <配置名>") }
    var config = loadConfig()
    guard config.profiles[args[1]] != nil else { fail("没有这个配置：\(args[1])") }
    config.activeProfile = args[1]
    saveConfig(config)
    print("✓ 已切到配置 \(args[1])")

case "status":
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-f", "UlanziDialNative.app/Contents/MacOS"]
    let pipe = Pipe()
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let running = (try? pipe.fileHandleForReading.readToEnd()).flatMap { $0 }.map { !$0.isEmpty } ?? false

    var battery = "未知"
    if let text = try? String(contentsOf: logURL, encoding: .utf8) {
        let patterns = ["battery(GATT) ", "battery (GATT) ", "battery "]
        for line in text.split(separator: "\n").reversed() {
            var matched = false
            for pattern in patterns {
                if let range = line.range(of: pattern) {
                    let tail = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    // 只认「数字 + %」这种，跳过 "characteristic found, reading…"
                    if tail.hasSuffix("%"), Int(tail.dropLast()) != nil {
                        battery = tail
                        matched = true
                        break
                    }
                }
            }
            if matched { break }
        }
    }
    print("app: \(running ? "运行中" : "未运行")")
    print("电量: \(battery)")
    print("配置: \(profileName(loadConfig()))")

default:
    print("""
    用法: ulanzidial <命令> [参数]

      list                      列出当前配置的全部槽位
      get <槽位>                 查看某个槽位
      set <槽位> <类型> <参数>    设置动作
      clear <槽位>              清除动作
      chord add <槽位+槽位> …    两键/三键组合
      chord list | clear        查看 / 清空组合
      layer add <按住键> <槽位> … 按住某键时的临时映射
      layer list | clear        查看 / 清空功能层
      mod add <修饰键> <槽位> …  按住 ⌃⌥⇧⌘ 时的另一套动作
      mod list | clear          查看 / 清空修饰键动作
      profiles                  列出所有配置
      use <配置名>               切换配置
      status                    查看运行状态与电量

    类型: key media app url text shell system sequence
    参数示例:
      ulanzidial set 顶部左键 key cmd+shift+4
      ulanzidial set 旋钮顺时针 media volumeUp
      ulanzidial set 左侧上键 app "/Applications/DaVinci Resolve.app"
      ulanzidial set 右侧下键 system showDesktop --double
      ulanzidial set 按下旋钮 system lockScreen --long

    选项: --double / --long / --profile <名字> / --json
    """)
}
