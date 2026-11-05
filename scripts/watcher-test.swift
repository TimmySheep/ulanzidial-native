import Foundation

// 验证「外部改写 config.json 后，App 内的 store 会自动重载」
let store = BindingStore()
let slot = Control.topLeft
print("初始 顶部左键 = \(store.binding(slot).describe)")

// 模拟 CLI：绕过 store.save()，直接原子替换配置文件
let dir = URL(fileURLWithPath: NSHomeDirectory())
    .appendingPathComponent("Library/Application Support/UlanziDialNative", isDirectory: true)
let url = dir.appendingPathComponent("config.json")

var config = ConfigFile(version: 3, activeProfile: "默认", profiles: [:], appRules: [:], doubleBindings: [:], longBindings: [:])
if let data = try? Data(contentsOf: url), let loaded = try? JSONDecoder().decode(ConfigFile.self, from: data) {
    config = loaded
}
var map = config.profiles["默认"] ?? [:]
map["01"] = Action(kind: .text, text: "watcher-ok")
config.profiles["默认"] = map
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
if let data = try? encoder.encode(config) {
    let tmp = dir.appendingPathComponent("config.test-tmp.json")
    try? data.write(to: tmp)
    _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
    print("已外部写入 config.json")
}

RunLoop.main.run(until: Date().addingTimeInterval(1.2))

let after = store.binding(slot).describe
print("重载后 顶部左键 = \(after)")
if after.contains("watcher-ok") {
    print("RESULT: PASS 热加载生效")
    exit(0)
} else {
    print("RESULT: FAIL 没有重载")
    exit(1)
}
