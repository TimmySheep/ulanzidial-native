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

    /// 界面展示顺序：顶部三键 → 四个侧键 → 旋钮
    static let ordered: [Control] = [
        .topLeft, .topMiddle, .topRight,
        .sideUpperLeft, .sideLowerLeft, .sideUpperRight, .sideLowerRight,
        .knobClick, .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW,
    ]

    var name: String {
        switch self {
        case .topLeft: return "顶部左键"
        case .topMiddle: return "顶部中键"
        case .topRight: return "顶部右键"
        case .sideUpperLeft: return "左侧上键"
        case .sideUpperRight: return "右侧上键"
        case .sideLowerLeft: return "左侧下键"
        case .sideLowerRight: return "右侧下键"
        case .knobClick: return "旋钮按下"
        case .rotateCCW: return "旋钮 ← 逆时针"
        case .rotateCW: return "旋钮 → 顺时针"
        case .knobHoldCCW: return "按住旋钮 ← 逆时针"
        case .knobHoldCW: return "按住旋钮 → 顺时针"
        }
    }

    var hint: String {
        switch self {
        case .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW: return "每转一格执行一次"
        default: return "按下执行一次"
        }
    }

    static func from(id: UInt8) -> Control? { Control(rawValue: Int(id)) }
}

// MARK: - 动作

enum ActionKind: String, Codable {
    case none
    case key
    case media
}

enum MediaKey: String, Codable, CaseIterable, Identifiable {
    case volumeUp
    case volumeDown
    case mute
    case playPause
    case nextTrack
    case previousTrack

    var id: String { rawValue }

    var name: String {
        switch self {
        case .volumeUp: return "音量 +"
        case .volumeDown: return "音量 −"
        case .mute: return "静音"
        case .playPause: return "播放/暂停"
        case .nextTrack: return "下一首"
        case .previousTrack: return "上一首"
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
        }
    }
}

struct Action: Codable, Equatable {
    var kind: ActionKind = .none
    var keyCode: UInt16?
    var modifiers: UInt?
    var keyLabel: String?
    var media: String?

    static let empty = Action()

    var describe: String {
        switch kind {
        case .none: return "未设置"
        case .key: return keyLabel ?? "未设置"
        case .media: return MediaKey(rawValue: media ?? "")?.name ?? "未设置"
        }
    }
}

// MARK: - 配置存储

final class BindingStore: ObservableObject {
    @Published private(set) var map: [Control: Action] = [:]

    private let storeURL: URL = {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/UlanziDialLite", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    init() {
        load()
    }

    func binding(_ c: Control) -> Action { map[c] ?? .empty }

    func set(_ c: Control, _ a: Action) {
        map[c] = a
        save()
    }

    private func load() {
        if let data = try? Data(contentsOf: storeURL),
           let decoded = try? JSONDecoder().decode([String: Action].self, from: data) {
            var loaded: [Control: Action] = [:]
            for (key, action) in decoded {
                if let raw = UInt8(key, radix: 16), let control = Control.from(id: raw) {
                    loaded[control] = action
                }
            }
            map = loaded
            logLine("config loaded: \(loaded.count) 项 from \(storeURL.path)")
        } else {
            // 首次运行：只给三个最自然的默认值，其余留空由用户自己设
            map = [
                .rotateCW: Action(kind: .media, media: MediaKey.volumeUp.rawValue),
                .rotateCCW: Action(kind: .media, media: MediaKey.volumeDown.rawValue),
                .knobClick: Action(kind: .media, media: MediaKey.mute.rawValue),
            ]
            save()
            logLine("config created with defaults at \(storeURL.path)")
        }
    }

    private func save() {
        var out: [String: Action] = [:]
        for (control, action) in map {
            out[String(format: "%02x", control.rawValue)] = action
        }
        if let data = try? JSONEncoder().encode(out) {
            try? data.write(to: storeURL)
        }
    }

    var configPath: String { storeURL.path }
}
