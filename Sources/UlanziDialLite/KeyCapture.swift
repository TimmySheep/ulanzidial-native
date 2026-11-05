import AppKit
import CoreGraphics

/// 录制快捷键时用 CGEventTap 抓全局按键。
/// 这样 ⌘Tab、⌥⌘Tab 这类被系统抢先处理的组合也能录到；
/// 抓到的按键会被吞掉，不会真的触发切换/系统行为。
final class KeyCapture {
    static let shared = KeyCapture()

    var onKey: ((NSEvent) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// 返回 false 表示无法创建 tap（通常是没给辅助功能权限），调用方应退回本地监听
    @discardableResult
    func start() -> Bool {
        stop()

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let port = KeyCapture.shared.tap {
                    CGEvent.tapEnable(tap: port, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            let capture = Unmanaged<KeyCapture>.fromOpaque(refcon).takeUnretainedValue()
            if let nsEvent = NSEvent(cgEvent: event) {
                DispatchQueue.main.async { capture.onKey?(nsEvent) }
            }
            // 吞掉，避免触发系统行为（如 ⌘Tab 切应用）
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logLine("key capture: tapCreate 失败（缺辅助功能权限？）")
            return false
        }

        self.tap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logLine("key capture started (CGEventTap)")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            CFMachPortInvalidate(tap)
        }
        tap = nil
        source = nil
    }
}
