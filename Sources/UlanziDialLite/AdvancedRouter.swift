import AppKit
import Foundation

/// 高级路由：键盘修饰键 + 槽位、多键组合、按住当功能层。
/// 顺序：修饰键 → 功能层 → 组合 → 普通（含双击/长按）
final class AdvancedRouter {
    private let store: BindingStore
    private let tracker: GestureTracker
    private let fireAction: (Control, Action, String) -> Void
    /// 读取当前键盘修饰键状态；测试时可注入假值
    private let readModifiers: () -> UInt

    private var held: Set<Control> = []
    private var consumed: Set<Control> = []
    private var pendingSingles: [Control: DispatchWorkItem] = [:]

    /// 组合判定窗口：第二个键要在这个时间内按下
    var chordWindow: TimeInterval = 0.22

    init(store: BindingStore,
         tracker: GestureTracker,
         readModifiers: @escaping () -> UInt = {
             UInt(CGEventSource.flagsState(.combinedSessionState).rawValue & 0x1E0000)
         },
         fireAction: @escaping (Control, Action, String) -> Void) {
        self.store = store
        self.tracker = tracker
        self.readModifiers = readModifiers
        self.fireAction = fireAction
    }

    private func slot(_ c: Control) -> String { String(format: "%02x", c.rawValue) }

    func down(_ c: Control) {
        held.insert(c)

        // 1) 键盘修饰键 + 槽位（零延迟）
        let mask = readModifiers() & 0x1E0000
        if mask != 0, let action = store.modifierAction(control: c, mask: mask), action.kind != .none {
            let label = modifierLabel(mask)
            fireAction(c, action, "\(label)+\(c.name)")
            consumed.insert(c)
            return
        }

        // 2) 功能层：某个层键正被按住时，其他槽位走层内映射
        for spec in store.layers where spec.hold != slot(c) {
            guard let holderValue = UInt8(spec.hold, radix: 16),
                  let holder = Control.from(id: holderValue),
                  held.contains(holder) else { continue }
            if let action = spec.bindings[slot(c)], action.kind != .none {
                fireAction(c, action, "功能层(\(holder.name))+\(c.name)")
                consumed.insert(c)
                return
            }
        }

        // 3) 组合：参与组合的键先压住不触发，等窗口内有没有第二个键
        if !c.isRotational, store.isChordKey(c) {
            if let spec = store.chord(matching: held) {
                for key in spec.keys {
                    if let v = UInt8(key, radix: 16), let other = Control.from(id: v) {
                        consumed.insert(other)
                        pendingSingles[other]?.cancel()
                        pendingSingles[other] = nil
                    }
                }
                fireAction(c, spec.action, "组合 \(spec.describe)")
                return
            }
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.pendingSingles[c] != nil else { return }
                self.pendingSingles[c] = nil
                if self.consumed.contains(c) { return }
                let action = self.store.action(c, gesture: .single)
                if action.kind != .none { self.fireAction(c, action, c.name) }
            }
            pendingSingles[c] = work
            DispatchQueue.main.asyncAfter(deadline: .now() + chordWindow, execute: work)
            return
        }

        // 4) 普通路径（含双击 / 长按）
        tracker.down(c)
    }

    func up(_ c: Control) {
        held.remove(c)

        if consumed.contains(c) {
            consumed.remove(c)
            return
        }

        // 组合窗口内就松手了 → 立即当作单击，避免手感发黏
        if let work = pendingSingles[c] {
            work.cancel()
            pendingSingles[c] = nil
            let action = store.action(c, gesture: .single)
            if action.kind != .none { fireAction(c, action, c.name) }
            return
        }

        tracker.up(c)
    }

    func reset() {
        held.removeAll()
        consumed.removeAll()
        for (_, work) in pendingSingles { work.cancel() }
        pendingSingles.removeAll()
        tracker.cancelAll()
    }

    private func modifierLabel(_ mask: UInt) -> String {
        var out = ""
        if mask & (1 << 18) != 0 { out += "⌃" }
        if mask & (1 << 19) != 0 { out += "⌥" }
        if mask & (1 << 17) != 0 { out += "⇧" }
        if mask & (1 << 20) != 0 { out += "⌘" }
        return out
    }
}
