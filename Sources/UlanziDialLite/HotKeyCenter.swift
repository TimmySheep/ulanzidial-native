import AppKit
import Carbon.HIToolbox

/// 全局快捷键：呼出设置窗口。使用 Carbon RegisterEventHotKey，不需要辅助功能权限。
/// 具体按键由 AppSettings 提供，可在设置界面里重新录制。
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    var onPress: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var installed = false

    /// 按当前设置（重新）注册
    func apply(settings: AppSettings) {
        installHandlerIfNeeded()
        unregister()

        guard settings.hotKeyEnabled else {
            logLine("global hotkey disabled")
            return
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5544_4C54), id: 1)
        let status = RegisterEventHotKey(
            UInt32(settings.hotKeyCode),
            settings.hotKeyCarbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        logLine("global hotkey \(settings.hotKeyLabel) register status=\(status)")
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { center.onPress?() }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        installed = true
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
