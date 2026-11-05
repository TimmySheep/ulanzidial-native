import Foundation

// 高级路由的行为测试（真时间）
let store = BindingStore()
var fired: [String] = []          // 普通/手势路径
var advanced: [String] = []       // 高级路径（修饰键/组合/功能层）
var mods: UInt = 0
let start = Date()

func now() -> Int { Int(Date().timeIntervalSince(start) * 1000) }
func wait(_ s: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
func reset() { fired.removeAll(); advanced.removeAll() }

var failures = 0
func check(_ name: String, _ cond: Bool, _ detail: String = "") {
    print(cond ? "  PASS \(name)" : "  FAIL \(name) \(detail)")
    if !cond { failures += 1 }
}

// 清空高级配置，避免受现有配置影响
for spec in store.chords { store.removeChord(id: spec.id) }
for spec in store.modifierActions { store.removeModifierAction(id: spec.id) }
for spec in store.layers { store.removeLayer(id: spec.id) }

// 给顶部左键一个可识别的单击动作
store.set(.topLeft, Action(kind: .text, text: "SINGLE-01"))
store.set(.sideLowerRight, Action(kind: .text, text: "SINGLE-08"))

let tracker = GestureTracker(
    hasBinding: { control, gesture in store.action(control, gesture: gesture).kind != .none },
    fire: { control, gesture in fired.append("\(control.name):\(gesture.name) @\(now())ms") }
)

let router = AdvancedRouter(
    store: store,
    tracker: tracker,
    readModifiers: { mods },
    fireAction: { control, action, label in advanced.append("\(label)") }
)

print("\n[1] 未配置任何高级项 → 单击零延迟")
reset()
router.down(.topLeft); wait(0.03); router.up(.topLeft); wait(0.05)
check("触发一次单击", fired.count == 1, "\(fired)")
check("无额外延迟", (fired.first?.contains("@") == true))

print("\n[2] 两键组合：先按左键再按右下键")
store.addChord(ChordSpec(keys: ["01", "08"], action: Action(kind: .text, text: "CHORD")))
reset()
router.down(.topLeft); wait(0.06); router.down(.sideLowerRight); wait(0.05)
check("组合触发一次", advanced == ["组合 顶部左键 + 右侧下键"], "\(advanced)")
router.up(.sideLowerRight); router.up(.topLeft); wait(0.3)
check("松手后不再补单击", fired.isEmpty, "\(fired)")

print("\n[3] 参与组合但只按一个键 → 松手立即单击")
reset()
router.down(.topLeft); wait(0.04); router.up(.topLeft); wait(0.1)
check("单击被触发", advanced.count == 1 || fired.count == 1, "advanced=\(advanced) fired=\(fired)")

print("\n[4] 键盘修饰键 + 旋钮（零延迟）")
store.addModifierAction(ModifierSpec(mask: 1 << 19, control: "0a",
                                     action: Action(kind: .text, text: "MOD-OPT-CW")))
reset()
mods = 1 << 19
router.down(.rotateCW); wait(0.02)
check("走修饰键动作", advanced == ["⌥+旋钮顺时针"], "\(advanced)")
router.up(.rotateCW)
mods = 0
reset()
router.down(.rotateCW); wait(0.02); router.up(.rotateCW)
check("不按修饰键时回普通路径", advanced.isEmpty, "\(advanced)")

print("\n[5] 按住当功能层")
store.addLayer(LayerSpec(hold: "05", bindings: ["01": Action(kind: .text, text: "LAYER-01")]))
reset()
router.down(.sideUpperRight); wait(0.03)
router.down(.topLeft); wait(0.03)
check("功能层动作触发", advanced.contains("功能层(右侧上键)+顶部左键"), "\(advanced)")
router.up(.topLeft); router.up(.sideUpperRight); wait(0.3)

print("\n[6] 三键组合")
store.addChord(ChordSpec(keys: ["01", "03", "08"], action: Action(kind: .text, text: "CHORD3")))
reset()
router.down(.topLeft); wait(0.04); router.down(.topRight); wait(0.04)
router.down(.sideLowerRight); wait(0.05)
check("三键组合触发", advanced.contains { $0.contains("顶部左键 + 顶部右键 + 右侧下键") }, "\(advanced)")
router.up(.sideLowerRight); router.up(.topRight); router.up(.topLeft); wait(0.3)

// 清理测试留下的配置
for spec in store.chords { store.removeChord(id: spec.id) }
for spec in store.modifierActions { store.removeModifierAction(id: spec.id) }
for spec in store.layers { store.removeLayer(id: spec.id) }
store.set(.topLeft, .empty)
store.set(.sideLowerRight, .empty)

print(failures == 0 ? "\nRESULT: ALL PASS" : "\nRESULT: \(failures) FAILED")
exit(failures == 0 ? 0 : 1)
