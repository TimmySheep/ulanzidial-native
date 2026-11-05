import AppKit
import ApplicationServices

// MARK: - 按键显示名

enum KeyLabel {
    static func name(keyCode: UInt16, characters: String?) -> String {
        let specials: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Space", 51: "Delete", 53: "Esc",
            115: "Home", 119: "End", 116: "PageUp", 121: "PageDown",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
            79: "F18", 80: "F19", 90: "F20",
        ]
        if let s = specials[keyCode] { return s }
        if let c = characters, !c.isEmpty {
            return c.uppercased()
        }
        return "Key\(keyCode)"
    }

    static func describe(_ event: NSEvent) -> String {
        describe(keyCode: event.keyCode, flags: event.modifierFlags, characters: event.charactersIgnoringModifiers)
    }

    static func describe(keyCode: UInt16, flags: NSEvent.ModifierFlags, characters: String?) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + name(keyCode: keyCode, characters: characters)
    }
}

// MARK: - 动作执行

enum Actions {
    static func perform(_ action: Action) {
        switch action.kind {
        case .none:
            return
        case .key:
            guard let code = action.keyCode else { return }
            keystroke(keyCode: code, modifiers: action.modifiers ?? 0)
        case .media:
            guard let raw = action.media, let key = MediaKey(rawValue: raw) else { return }
            mediaKey(key)
        }
    }

    private static func keystroke(keyCode: UInt16, modifiers: UInt) {
        guard isAccessibilityGranted() else {
            logLine("按键失败：未获得辅助功能权限")
            return
        }
        let source = CGEventSource(stateID: .combinedSessionState)
        let flags = CGEventFlags(rawValue: UInt64(modifiers))
        if let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }
    }

    private static func mediaKey(_ key: MediaKey) {
        for isDown in [true, false] {
            let data1 = Int((key.nxKey << 16) | (isDown ? 0x0A00 : 0x0B00))
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
    }

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 弹系统授权提示并把 App 加进「辅助功能」列表
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
