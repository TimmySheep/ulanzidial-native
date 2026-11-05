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

    static func from(id: UInt8) -> Control? { Control(rawValue: Int(id)) }
}

// MARK: - 动作类型

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case none
    case key
    case media
    case text
    case app
    case url
    case shell
    case system

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
        }
    }
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

    init() { load() }

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
            logLine("config loaded: \(loaded.count) 项")
        } else {
            // 首次运行只给最自然的三个默认值，其余留给用户自己设
            map = [
                .rotateCW: Action(kind: .media, media: MediaKey.volumeUp.rawValue),
                .rotateCCW: Action(kind: .media, media: MediaKey.volumeDown.rawValue),
                .knobClick: Action(kind: .media, media: MediaKey.mute.rawValue),
            ]
            save()
            logLine("config created with defaults")
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
