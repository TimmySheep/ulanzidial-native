import Foundation

// 判定逻辑的时序用例（不是单元框架，直接跑真时间）
var fired: [(ClickGesture, Int)] = []   // (手势, 毫秒)
var bindings: Set<ClickGesture> = []

let tracker = GestureTracker(
    config: .init(longPressDelay: 0.45, doubleWindow: 0.28),
    hasBinding: { _, g in bindings.contains(g) },
    fire: { _, g in
        fired.append((g, Int(Date().timeIntervalSince(start) * 1000)))
        print("  fire \(g.name) @ \(Int(Date().timeIntervalSince(start) * 1000))ms")
    }
)

let start = Date()
func wait(_ s: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
func reset() { fired.removeAll() }
var failures = 0
func check(_ name: String, _ cond: Bool) {
    print(cond ? "  PASS \(name)" : "  FAIL \(name)")
    if !cond { failures += 1 }
}

let key = Control.topLeft
let knob = Control.rotateCW

print("\n[1] 只有单击：按下即触发，零延迟")
bindings = [.single]
reset()
tracker.down(key); wait(0.02); tracker.up(key); wait(0.05)
check("触发一次单击", fired.map { $0.0 } == [.single])
check("耗时 < 50ms", (fired.first?.1 ?? 999) < 50)

print("\n[2] 单击 + 双击：单击要等过双击窗口")
bindings = [.single, .double]
reset()
tracker.down(key); wait(0.03); tracker.up(key); wait(0.45)
check("最终触发单击", fired.map { $0.0 } == [.single])
check("延迟 >= 260ms", (fired.first?.1 ?? 0) >= 260)

print("\n[3] 快速两下：只出双击，不出单击")
bindings = [.single, .double]
reset()
tracker.down(key); wait(0.04); tracker.up(key); wait(0.06)
tracker.down(key); wait(0.04); tracker.up(key); wait(0.45)
check("只触发双击", fired.map { $0.0 } == [.double])

print("\n[4] 长按：到点触发长按，松手不补单击")
bindings = [.single, .long]
reset()
tracker.down(key); wait(0.6); tracker.up(key); wait(0.4)
check("只触发长按", fired.map { $0.0 } == [.long])
check("长按在 450ms 后触发", (fired.first?.1 ?? 0) >= 430)

print("\n[5] 短按（带长按绑定）：松手即单击")
bindings = [.single, .long]
reset()
tracker.down(key); wait(0.08); tracker.up(key); wait(0.1)
check("触发单击", fired.map { $0.0 } == [.single])

print("\n[6] 旋钮转动：直通，不进手势判定")
bindings = [.single, .double, .long]
reset()
for _ in 0..<3 { tracker.down(knob); wait(0.01) }
wait(0.05)
check("三格触发三次", fired.count == 3 && fired.allSatisfy { $0.0 == .single })

print("\n[7] 单击 + 单击（间隔 > 窗口）：两次单击")
bindings = [.single, .double]
reset()
tracker.down(key); wait(0.03); tracker.up(key); wait(0.35)
tracker.down(key); wait(0.03); tracker.up(key); wait(0.4)
check("两次单击", fired.map { $0.0 } == [.single, .single])

print(failures == 0 ? "\nRESULT: ALL PASS" : "\nRESULT: \(failures) FAILED")
exit(failures == 0 ? 0 : 1)
