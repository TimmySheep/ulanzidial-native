import AppKit
import Carbon.HIToolbox
import Foundation

/// 应用级偏好（全局快捷键等），存 UserDefaults
final class AppSettings: ObservableObject {
    @Published var hotKeyEnabled: Bool { didSet { save() } }
    @Published var hotKeyCode: UInt16 { didSet { save() } }
    @Published var hotKeyCarbonModifiers: UInt32 { didSet { save() } }
    @Published var hotKeyLabel: String { didSet { save() } }

    private let defaults = UserDefaults.standard

    init() {
        let hasValue = defaults.object(forKey: "hotKeyCode") != nil
        if hasValue {
            // hotKeyEnabled 单独判断：老版本可能只存了 code，未存开关时默认开启
            hotKeyEnabled = defaults.object(forKey: "hotKeyEnabled") == nil
                ? true
                : defaults.bool(forKey: "hotKeyEnabled")
            hotKeyCode = UInt16(defaults.integer(forKey: "hotKeyCode"))
            hotKeyCarbonModifiers = UInt32(defaults.integer(forKey: "hotKeyModifiers"))
            hotKeyLabel = defaults.string(forKey: "hotKeyLabel") ?? "⌥⌘D"
        } else {
            // 默认 ⌥⌘D
            hotKeyEnabled = true
            hotKeyCode = 2
            hotKeyCarbonModifiers = UInt32(cmdKey | optionKey)
            hotKeyLabel = "⌥⌘D"
        }
    }

    private func save() {
        defaults.set(hotKeyEnabled, forKey: "hotKeyEnabled")
        defaults.set(Int(hotKeyCode), forKey: "hotKeyCode")
        defaults.set(Int(hotKeyCarbonModifiers), forKey: "hotKeyModifiers")
        defaults.set(hotKeyLabel, forKey: "hotKeyLabel")
    }
}

// Carbon 修饰键常量由 Carbon.HIToolbox 提供：cmdKey / shiftKey / optionKey / controlKey

extension NSEvent.ModifierFlags {
    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if contains(.command) { mask |= UInt32(cmdKey) }
        if contains(.shift) { mask |= UInt32(shiftKey) }
        if contains(.option) { mask |= UInt32(optionKey) }
        if contains(.control) { mask |= UInt32(controlKey) }
        return mask
    }
}
