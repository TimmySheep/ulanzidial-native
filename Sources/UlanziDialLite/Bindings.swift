import AppKit
import Foundation

// MARK: - 可控槽位（设备上报的事件 ID）

enum Control: Int, CaseIterable, Codable, Hashable {
    case topLeft = 0x01
    case topMiddle = 0x02
    case topRight = 0x03
    case sideUpperLeft = 0x04
    case sideUpperRight = 0x05
    case sideLowerLeft = 0x06
    case knobClick = 0x07
    case sideLowerRight = 0x08
    case rotateCCW = 0x09
    case rotateCW = 0x0A
    case knobHoldCCW = 0x0B
    case knobHoldCW = 0x0C

    static let topRow: [Control] = [.topLeft, .topMiddle, .topRight]
    static let sideRow: [Control] = [.sideUpperLeft, .sideLowerLeft, .sideUpperRight, .sideLowerRight]
    static let knobGroup: [Control] = [.knobClick, .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW]
    static var ordered: [Control] { topRow + sideRow + knobGroup }

    var name: String {
        switch self {
        case .topLeft: return "顶部左键"
        case .topMiddle: return "顶部中键"
        case .topRight: return "顶部右键"
        case .sideUpperLeft: return "左侧上键"
        case .sideUpperRight: return "右侧上键"
        case .sideLowerLeft: return "左侧下键"
        case .sideLowerRight: return "右侧下键"
        case .knobClick: return "按下旋钮"
        case .rotateCCW: return "旋钮逆时针"
        case .rotateCW: return "旋钮顺时针"
        case .knobHoldCCW: return "按住转 · 逆时针"
        case .knobHoldCW: return "按住转 · 顺时针"
        }
    }

    var symbol: String {
        switch self {
        case .topLeft: return "1.square"
        case .topMiddle: return "2.square"
        case .topRight: return "3.square"
        case .sideUpperLeft: return "4.square"
        case .sideLowerLeft: return "5.square"
        case .sideUpperRight: return "6.square"
        case .sideLowerRight: return "7.square"
        case .knobClick: return "circle.circle"
        case .rotateCCW: return "arrow.counterclockwise"
        case .rotateCW: return "arrow.clockwise"
        case .knobHoldCCW: return "arrow.counterclockwise.circle"
        case .knobHoldCW: return "arrow.clockwise.circle"
        }
    }

    var hint: String {
        switch self {
        case .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW: return "每转一格一次"
        default: return "按下一次"
        }
    }

    /// 转动类：离散事件、可连续重复，不参与单击/双击/长按判定
    var isRotational: Bool {
        switch self {
        case .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW: return true
        default: return false
        }
    }

    static func from(id: UInt8) -> Control? { Control(rawValue: Int(id)) }
}

// MARK: - 动作类型

/// 同一个键的三种点击手势（Action Combination）
enum ClickGesture: String, Codable, CaseIterable, Identifiable {
    case single, double, long

    var id: String { rawValue }

    var name: String {
        switch self {
        case .single: return "单击"
        case .double: return "双击"
        case .long:   return "长按"
        }
    }
}

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case none
    case key
    case media
    case text
    case app
    case url
    case shell
    case system
    case sequence

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "无"
        case .key: return "键盘快捷键"
        case .media: return "系统媒体键"
        case .text: return "输入文字"
        case .app: return "打开 App"
        case .url: return "打开网址/文件"
        case .shell: return "运行命令"
        case .system: return "系统操作"
        case .sequence: return "多项操作"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "minus.circle"
        case .key: return "keyboard"
        case .media: return "speaker.wave.2"
        case .text: return "text.cursor"
        case .app: return "app.badge"
        case .url: return "link"
        case .shell: return "terminal"
        case .system: return "gearshape.2"
        case .sequence: return "list.bullet.rectangle"
        }
    }
}

/// 多项操作里的一步：动作 + 执行后等待多久再做下一步
struct Step: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var action: Action = .empty
    var delayMs: Int = 120
}

enum MediaKey: String, Codable, CaseIterable, Identifiable {
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case nextTrack
    case previousTrack
    case brightnessUp
    case brightnessDown

    var id: String { rawValue }

    var name: String {
        switch self {
        case .volumeUp: return "音量 +"
        case .volumeDown: return "音量 −"
        case .mute: return "静音开关"
        case .playPause: return "播放 / 暂停"
        case .nextTrack: return "下一首"
        case .previousTrack: return "上一首"
        case .brightnessUp: return "屏幕亮度 +"
        case .brightnessDown: return "屏幕亮度 −"
        }
    }

    /// NX_KEYTYPE_* 常量
    var nxKey: Int32 {
        switch self {
        case .volumeUp: return 0
        case .volumeDown: return 1
        case .mute: return 7
        case .playPause: return 16
        case .nextTrack: return 17
        case .previousTrack: return 18
        case .brightnessUp: return 2
        case .brightnessDown: return 3
        }
    }
}

enum SystemAction: String, Codable, CaseIterable, Identifiable {
    case lockScreen
    case sleepDisplay
    case sleepMac
    case screenSaver
    case screenshotFull
    case screenshotArea
    case screenshotOptions
    case missionControl
    case appExpose
    case launchpad
    case showDesktop
    case toggleDarkMode

    var id: String { rawValue }

    var name: String {
        switch self {
        case .lockScreen: return "锁定屏幕"
        case .sleepDisplay: return "关闭显示器"
        case .sleepMac: return "睡眠"
        case .screenSaver: return "启动屏幕保护"
        case .screenshotFull: return "截屏 · 全屏"
        case .screenshotArea: return "截屏 · 选区"
        case .screenshotOptions: return "截屏 · 工具栏"
        case .missionControl: return "调度中心"
        case .appExpose: return "应用窗口"
        case .launchpad: return "启动台"
        case .showDesktop: return "显示桌面"
        case .toggleDarkMode: return "切换深色 / 浅色"
        }
    }
}

struct Action: Codable, Equatable {
    var kind: ActionKind = .none
    var keyCode: UInt16?
    var modifiers: UInt?
    var keyLabel: String?
    var media: String?
    var text: String?
    var path: String?
    var url: String?
    var command: String?
    var system: String?
    var steps: [Step]?

    static let empty = Action()

    var describe: String {
        switch kind {
        case .none: return "未设置"
        case .key: return keyLabel ?? "未设置"
        case .media: return MediaKey(rawValue: media ?? "")?.name ?? "未设置"
        case .text: return "「\(text ?? "")」"
        case .app: return path.map { ($0 as NSString).lastPathComponent } ?? "未选择"
        case .url: return url ?? "未填写"
        case .shell: return command ?? "未填写"
        case .system: return SystemAction(rawValue: system ?? "")?.name ?? "未设置"
        case .sequence:
            let count = steps?.count ?? 0
            return count == 0 ? "空的多项操作" : "\(count) 步操作"
        }
    }
}

// MARK: - 配置存储

final class BindingStore: ObservableObject {
    @Published private(set) var profiles: [String: [Control: Action]] = [:]
    @Published private(set) var doubleMap: [String: [Control: Action]] = [:]
    @Published private(set) var longMap: [String: [Control: Action]] = [:]
    @Published private(set) var chords: [ChordSpec] = []
    @Published private(set) var modifierActions: [ModifierSpec] = []
    @Published private(set) var layers: [LayerSpec] = []
    @Published private(set) var activeProfile: String = "默认"
    @Published private(set) var appRules: [String: String] = [:]

    private let storeURL: URL = {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/UlanziDialNative", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    init() {
        load()
        startWatching()
    }

    func binding(_ c: Control) -> Action { profiles[activeProfile]?[c] ?? .empty }

    func doubleBinding(_ c: Control) -> Action { doubleMap[activeProfile]?[c] ?? .empty }
    func longBinding(_ c: Control) -> Action { longMap[activeProfile]?[c] ?? .empty }

    /// 按手势取当前动作
    func action(_ c: Control, gesture: ClickGesture) -> Action {
        switch gesture {
        case .single: return binding(c)
        case .double: return doubleBinding(c)
        case .long:   return longBinding(c)
        }
    }

    /// 这个键是否有单击以外的绑定（决定要不要延迟判定双击）
    func hasExtraGestures(_ c: Control) -> Bool {
        doubleBinding(c).kind != .none || longBinding(c).kind != .none
    }

    // MARK: 高级组合

    func chordKeys(for c: Control) -> Set<Control> {
        let slot = String(format: "%02x", c.rawValue)
        var out: Set<Control> = []
        for chord in chords where chord.keys.contains(slot) {
            for raw in chord.keys {
                if let v = UInt8(raw, radix: 16), let other = Control.from(id: v) { out.insert(other) }
            }
        }
        return out
    }

    func isChordKey(_ c: Control) -> Bool {
        let slot = String(format: "%02x", c.rawValue)
        return chords.contains { $0.keys.contains(slot) }
    }

    func chord(matching held: Set<Control>) -> ChordSpec? {
        chords.first { spec in
            var controls: Set<Control> = []
            for raw in spec.keys {
                guard let v = UInt8(raw, radix: 16), let c = Control.from(id: v) else { return false }
                controls.insert(c)
            }
            return controls == held
        }
    }

    func modifierAction(control: Control, mask: UInt) -> Action? {
        let slot = String(format: "%02x", control.rawValue)
        return modifierActions.first { $0.control == slot && $0.mask == mask }?.action
    }

    func layer(holding control: Control) -> LayerSpec? {
        let slot = String(format: "%02x", control.rawValue)
        return layers.first { $0.hold == slot }
    }

    func addChord(_ spec: ChordSpec) {
        chords.append(spec)
        save()
        logLine("store.addChord \(spec.describe)")
    }

    func removeChord(id: UUID) {
        chords.removeAll { $0.id == id }
        save()
    }

    func addModifierAction(_ spec: ModifierSpec) {
        modifierActions.append(spec)
        save()
        logLine("store.addModifier \(spec.maskLabel)+\(spec.control)")
    }

    func removeModifierAction(id: UUID) {
        modifierActions.removeAll { $0.id == id }
        save()
    }

    func addLayer(_ spec: LayerSpec) {
        layers.append(spec)
        save()
        logLine("store.addLayer hold=\(spec.hold) \(spec.bindings.count) 项")
    }

    func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
        save()
    }

    func set(_ c: Control, gesture: ClickGesture, _ a: Action) {
        switch gesture {
        case .single:
            set(c, a)
        case .double:
            var map = doubleMap[activeProfile] ?? [:]
            map[c] = a
            doubleMap[activeProfile] = map
            logLine("store.set [\(activeProfile)] \(c.name) 双击 -> \(a.kind.rawValue)/\(a.describe)")
            save()
        case .long:
            var map = longMap[activeProfile] ?? [:]
            map[c] = a
            longMap[activeProfile] = map
            logLine("store.set [\(activeProfile)] \(c.name) 长按 -> \(a.kind.rawValue)/\(a.describe)")
            save()
        }
    }

    func set(_ c: Control, _ a: Action) {
        var map = profiles[activeProfile] ?? [:]
        map[c] = a
        profiles[activeProfile] = map
        logLine("store.set [\(activeProfile)] \(c.name) -> \(a.kind.rawValue)/\(a.describe)")
        save()
    }

    // MARK: 配置（profile）

    var profileNames: [String] { profiles.keys.sorted() }

    func switchTo(_ name: String, reason: String = "") {
        guard profiles[name] != nil, name != activeProfile else { return }
        activeProfile = name
        logLine("profile -> \(name) \(reason)")
        save()
    }

    func addProfile(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, profiles[trimmed] == nil else { return }
        profiles[trimmed] = [:]
        activeProfile = trimmed
        save()
    }

    func deleteProfile(_ name: String) {
        guard name != "默认", profiles.count > 1 else { return }
        profiles.removeValue(forKey: name)
        doubleMap.removeValue(forKey: name)
        longMap.removeValue(forKey: name)
        for (bundle, target) in appRules where target == name {
            appRules.removeValue(forKey: bundle)
        }
        if activeProfile == name { activeProfile = "默认" }
        save()
    }

    // MARK: 应用规则

    func setRule(bundleID: String, profile: String) {
        guard profiles[profile] != nil else { return }
        appRules[bundleID] = profile
        save()
    }

    func removeRule(bundleID: String) {
        appRules.removeValue(forKey: bundleID)
        save()
    }

    /// 前台 App 变化时调用：该 App 有规则就切到对应配置，否则回默认
    func applyAppRule(bundleID: String?) {
        let target = (bundleID.flatMap { appRules[$0] }) ?? "默认"
        switchTo(target, reason: "app=\(bundleID ?? "-")")
    }

    /// 启动时留一份上次的配置，防止误清空或写坏后无法回滚
    private func backupExisting() {
        let backup = storeURL.deletingLastPathComponent().appendingPathComponent("config.previous.json")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.copyItem(at: storeURL, to: backup)
    }

    private func load() {
        // 从旧名字迁移配置（改过两次名：UlanziDialLite → DialNative → UlanziDialNative）
        if !FileManager.default.fileExists(atPath: storeURL.path) {
            for oldName in ["DialNative", "UlanziDialLite"] {
                let legacy = URL(fileURLWithPath: NSHomeDirectory())
                    .appendingPathComponent("Library/Application Support/\(oldName)/config.json")
                if FileManager.default.fileExists(atPath: legacy.path) {
                    try? FileManager.default.copyItem(at: legacy, to: storeURL)
                    logLine("config migrated from \(oldName)")
                    break
                }
            }
        }

        backupExisting()
        guard let data = try? Data(contentsOf: storeURL) else {
            profiles = ["默认": BindingStore.defaultBindings()]
            save()
            logLine("config created with defaults")
            return
        }

        // v2：多配置
        if let config = try? JSONDecoder().decode(ConfigFile.self, from: data) {
            var decoded: [String: [Control: Action]] = [:]
            for (name, raw) in config.profiles {
                decoded[name] = BindingStore.decodeBindings(raw)
            }
            profiles = decoded
            appRules = config.appRules ?? [:]
            doubleMap = BindingStore.decodeMaps(config.doubleBindings)
            longMap = BindingStore.decodeMaps(config.longBindings)
            chords = config.chords ?? []
            modifierActions = config.modifierActions ?? []
            layers = config.layers ?? []
            let wanted = config.activeProfile ?? "默认"
            activeProfile = decoded[wanted] != nil ? wanted : (decoded.keys.sorted().first ?? "默认")
            logLine("config loaded: \(decoded.count) 个配置, \(appRules.count) 条应用规则, 双击 \(doubleMap.values.reduce(0) { $0 + $1.count }) 项, 长按 \(longMap.values.reduce(0) { $0 + $1.count }) 项")
            return
        }

        // v1：扁平 map → 迁移为「默认」配置
        if let legacy = try? JSONDecoder().decode([String: Action].self, from: data) {
            profiles = ["默认": BindingStore.decodeBindings(legacy)]
            appRules = [:]
            activeProfile = "默认"
            logLine("config migrated v1 -> v2: \(legacy.count) 项")
            save()
            return
        }

        profiles = ["默认": BindingStore.defaultBindings()]
        save()
    }

    private func save() {
        var encoded: [String: [String: Action]] = [:]
        for (name, map) in profiles {
            encoded[name] = BindingStore.encodeBindings(map)
        }
        let config = ConfigFile(
            version: 4,
            activeProfile: activeProfile,
            profiles: encoded,
            appRules: appRules,
            doubleBindings: BindingStore.encodeMaps(doubleMap),
            longBindings: BindingStore.encodeMaps(longMap),
            chords: chords,
            modifierActions: modifierActions,
            layers: layers
        )
        if let data = try? JSONEncoder().encode(config) {
            lastSelfWrite = Date()
            try? data.write(to: storeURL)
        }
    }

    // MARK: 外部改动（CLI 写入）后自动生效

    private var fileWatcher: DispatchSourceFileSystemObject?
    private var lastSelfWrite = Date.distantPast

    private func startWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
        let fd = open(storeURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // 自己刚写完不必重读
            if Date().timeIntervalSince(self.lastSelfWrite) < 0.35 { return }
            self.reloadFromDisk()
            self.startWatching()
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileWatcher = source
    }

    func reloadFromDisk() {
        guard let data = try? Data(contentsOf: storeURL),
              let config = try? JSONDecoder().decode(ConfigFile.self, from: data) else { return }
        var decoded: [String: [Control: Action]] = [:]
        for (name, raw) in config.profiles {
            decoded[name] = BindingStore.decodeBindings(raw)
        }
        guard !decoded.isEmpty else { return }
        profiles = decoded
        doubleMap = BindingStore.decodeMaps(config.doubleBindings)
        longMap = BindingStore.decodeMaps(config.longBindings)
        appRules = config.appRules ?? [:]
        let wanted = config.activeProfile ?? activeProfile
        if decoded[wanted] != nil { activeProfile = wanted }
        logLine("config reloaded from disk (external change)")
    }

    private static func encodeMaps(_ input: [String: [Control: Action]]) -> [String: [String: Action]] {
        var out: [String: [String: Action]] = [:]
        for (name, map) in input { out[name] = encodeBindings(map) }
        return out
    }

    private static func decodeMaps(_ raw: [String: [String: Action]]?) -> [String: [Control: Action]] {
        guard let raw else { return [:] }
        var out: [String: [Control: Action]] = [:]
        for (name, map) in raw { out[name] = decodeBindings(map) }
        return out
    }

    private static func encodeBindings(_ map: [Control: Action]) -> [String: Action] {
        var out: [String: Action] = [:]
        for (control, action) in map {
            out[String(format: "%02x", control.rawValue)] = action
        }
        return out
    }

    private static func decodeBindings(_ raw: [String: Action]) -> [Control: Action] {
        var out: [Control: Action] = [:]
        for (key, action) in raw {
            if let value = UInt8(key, radix: 16), let control = Control.from(id: value) {
                out[control] = action
            }
        }
        return out
    }

    private static func defaultBindings() -> [Control: Action] {
        [
            .rotateCW: Action(kind: .media, media: MediaKey.volumeUp.rawValue),
            .rotateCCW: Action(kind: .media, media: MediaKey.volumeDown.rawValue),
            .knobClick: Action(kind: .media, media: MediaKey.mute.rawValue),
        ]
    }

    var configPath: String { storeURL.path }
}

struct ConfigFile: Codable {
    var version: Int
    var activeProfile: String?
    var profiles: [String: [String: Action]]
    var appRules: [String: String]?
    /// 双击 / 长按绑定（v3 新增，旧配置里没有这两个字段）
    var doubleBindings: [String: [String: Action]]?
    var longBindings: [String: [String: Action]]?
    /// 高级组合（v4 新增）
    var chords: [ChordSpec]?
    var modifierActions: [ModifierSpec]?
    var layers: [LayerSpec]?
}

// MARK: - 高级组合

/// 两键 / 三键同时按住
struct ChordSpec: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var keys: [String]          // 槽位 ID，如 ["01", "08"]
    var action: Action
    var describe: String {
        let names = keys.compactMap { raw -> String? in
            guard let v = UInt8(raw, radix: 16), let c = Control.from(id: v) else { return nil }
            return c.name
        }
        return names.joined(separator: " + ")
    }
}

/// 按住键盘修饰键时，某个槽位改走另一套动作（零延迟）
struct ModifierSpec: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var mask: UInt              // CGEventFlags：⌃ 1<<18、⌥ 1<<19、⇧ 1<<17、⌘ 1<<20
    var control: String
    var action: Action

    var maskLabel: String {
        var out = ""
        if mask & (1 << 18) != 0 { out += "⌃" }
        if mask & (1 << 19) != 0 { out += "⌥" }
        if mask & (1 << 17) != 0 { out += "⇧" }
        if mask & (1 << 20) != 0 { out += "⌘" }
        return out.isEmpty ? "（无）" : out
    }
}

/// 按住某个键时，其他槽位临时换成另一套映射（类似 Fn 层）
struct LayerSpec: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var hold: String                    // 触发层的槽位 ID
    var bindings: [String: Action]      // 该层下其他槽位的动作

    var holdName: String {
        guard let v = UInt8(hold, radix: 16), let c = Control.from(id: v) else { return hold }
        return c.name
    }
}
