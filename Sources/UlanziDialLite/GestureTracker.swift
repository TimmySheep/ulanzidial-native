import Foundation

/// 单击 / 双击 / 长按判定。
/// 不依赖 UI，也不依赖设备，只吃 down/up 事件，便于单独测试。
final class GestureTracker {
    struct Config {
        var longPressDelay: TimeInterval = 0.45
        var doubleWindow: TimeInterval = 0.28
    }

    private struct State {
        var clicks = 0
        var longFired = false
        var upAt: Date = .distantPast
        var longTimer: Timer?
        var singleTimer: Timer?
    }

    private var states: [Control: State] = [:]
    private let config: Config
    /// 这个键是否绑了双击 / 长按（没绑就不做延迟判定）
    private let hasBinding: (Control, ClickGesture) -> Bool
    private let fire: (Control, ClickGesture) -> Void

    init(config: Config = Config(),
         hasBinding: @escaping (Control, ClickGesture) -> Bool,
         fire: @escaping (Control, ClickGesture) -> Void) {
        self.config = config
        self.hasBinding = hasBinding
        self.fire = fire
    }

    func down(_ c: Control) {
        if c.isRotational {
            fire(c, .single)
            return
        }

        var s = states[c] ?? State()
        let now = Date()
        let wantsDouble = hasBinding(c, .double)

        // 第二下落在窗口内 → 双击
        if s.clicks == 1, s.singleTimer != nil, wantsDouble,
           now.timeIntervalSince(s.upAt) < config.doubleWindow {
            s.singleTimer?.invalidate()
            s.singleTimer = nil
            s.clicks = 0
            s.longFired = true      // 松手时不再补单击
            states[c] = s
            fire(c, .double)
            return
        }

        s.clicks = 1
        s.longFired = false
        s.singleTimer?.invalidate()
        s.singleTimer = nil

        if hasBinding(c, .long) {
            s.longTimer?.invalidate()
            s.longTimer = Timer.scheduledTimer(withTimeInterval: config.longPressDelay, repeats: false) { [weak self] _ in
                guard let self, var st = self.states[c], st.clicks == 1, !st.longFired else { return }
                st.longFired = true
                st.clicks = 0
                st.longTimer = nil
                self.states[c] = st
                self.fire(c, .long)
            }
        }
        states[c] = s
    }

    func up(_ c: Control) {
        if c.isRotational { return }
        guard var s = states[c] else { return }
        s.upAt = Date()
        s.longTimer?.invalidate()
        s.longTimer = nil

        if s.longFired {
            s.longFired = false
            s.clicks = 0
            states[c] = s
            return
        }

        guard s.clicks == 1 else {
            states[c] = s
            return
        }

        if hasBinding(c, .double) {
            s.singleTimer?.invalidate()
            s.singleTimer = Timer.scheduledTimer(withTimeInterval: config.doubleWindow, repeats: false) { [weak self] _ in
                guard let self, var st = self.states[c], st.clicks == 1 else { return }
                st.clicks = 0
                st.singleTimer = nil
                self.states[c] = st
                self.fire(c, .single)
            }
            states[c] = s
        } else {
            s.clicks = 0
            states[c] = s
            fire(c, .single)
        }
    }

    func cancelAll() {
        for (_, var s) in states {
            s.longTimer?.invalidate()
            s.singleTimer?.invalidate()
            s.clicks = 0
        }
        states.removeAll()
    }
}
