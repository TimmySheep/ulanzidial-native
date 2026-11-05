import AppKit
import Carbon.HIToolbox
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: BindingStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var link: DialLink

    enum Selection: Hashable {
        case control(Control)
        case general
    }

    @State private var selection: Selection = .control(.topLeft)
    @State private var editing: Control?
    @State private var recordingHotKey = false
    @State private var monitor: Any?
    @State private var trusted = Actions.isAccessibilityGranted()
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginNote: String?
    @State private var creatingProfile = false
    @State private var newProfileName = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if selection == .general {
                generalPane
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.96, green: 0.97, blue: 1.0), Color(red: 0.92, green: 0.93, blue: 0.99)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                DeviceTopView(store: store, selection: $selection, editing: $editing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.96, green: 0.97, blue: 1.0), Color(red: 0.90, green: 0.92, blue: 0.99)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onDisappear { stopMonitor() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = Actions.isAccessibilityGranted()
            loginEnabled = LoginItem.isEnabled
        }
        .alert("新建配置", isPresented: $creatingProfile) {
            TextField("配置名称", text: $newProfileName)
            Button("创建") { store.addProfile(newProfileName) }
            Button("取消", role: .cancel) { }
        } message: {
            Text("新配置初始为空，可以单独为它设置每个按键。")
        }
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("UlanziDial Native").font(.system(size: 17, weight: .semibold))

            HStack(spacing: 5) {
                Circle()
                    .fill(link.isOnline ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(link.isOnline ? "已连接" : link.stateText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: batterySymbol)
                    .font(.system(size: 12))
                    .foregroundStyle(link.batteryText == "—" ? Color.secondary : Color.green)
                Text("电量 \(link.batteryText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("点击设备上的任意按键设置动作")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if selection != .general {
                Menu {
                    ForEach(store.profileNames, id: \.self) { name in
                        Button {
                            store.switchTo(name)
                        } label: {
                            if name == store.activeProfile {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                    Divider()
                    Button("新建配置…") {
                        newProfileName = ""
                        creatingProfile = true
                    }
                    Button("删除当前配置") {
                        store.deleteProfile(store.activeProfile)
                    }
                    .disabled(store.activeProfile == "默认")
                } label: {
                    Label(store.activeProfile, systemImage: "square.stack.3d.up")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                Button {
                    selection = .general
                    editing = nil
                    if recordingHotKey { stopMonitor(); recordingHotKey = false }
                } label: {
                    Label("通用", systemImage: "gearshape")
                        .font(.system(size: 12))
                }
                .controlSize(.small)
            }

            Button {
                link.reconnect()
            } label: {
                Label("重新连接", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassBar()
    }

    // MARK: 通用

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button {
                    selection = .control(.topLeft)
                } label: {
                    Label("返回按键设置", systemImage: "chevron.left")
                        .font(.system(size: 12))
                }
                .buttonStyle(.link)

                Text("通用").font(.system(size: 20, weight: .semibold))

                Divider()

                HStack(spacing: 12) {
                    Text("呼出窗口")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Button {
                        startHotKeyRecording()
                    } label: {
                        Text(recordingHotKey ? "请按新的快捷键…（Esc 取消）" : settings.hotKeyLabel)
                            .font(.system(size: 12))
                            .frame(minWidth: 170, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!settings.hotKeyEnabled)

                    Toggle("启用", isOn: Binding(
                        get: { settings.hotKeyEnabled },
                        set: { newValue in
                            settings.hotKeyEnabled = newValue
                            HotKeyCenter.shared.apply(settings: settings)
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Button("恢复默认") {
                        settings.hotKeyCode = 2
                        settings.hotKeyCarbonModifiers = UInt32(cmdKey | optionKey)
                        settings.hotKeyLabel = "⌥⌘D"
                        settings.hotKeyEnabled = true
                        HotKeyCenter.shared.apply(settings: settings)
                    }
                    .controlSize(.small)
                }

                Text("App 不占菜单栏和 Dock，这是唯一能打开设置窗口的入口；快捷键至少要带一个修饰键。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 96)

                Divider()

                HStack(spacing: 12) {
                    Text("开机自启")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Toggle("登录时自动启动", isOn: Binding(
                        get: { loginEnabled },
                        set: { newValue in
                            if let error = LoginItem.setEnabled(newValue) {
                                loginNote = "设置失败：\(error)"
                            } else {
                                loginNote = nil
                            }
                            loginEnabled = LoginItem.isEnabled
                        }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    Text(LoginItem.statusText).font(.system(size: 11)).foregroundStyle(.secondary)
                    if LoginItem.isEnabled {
                        Button("在系统设置中查看") { LoginItem.openLoginItemsSettings() }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                    }
                }

                if let note = loginNote {
                    Text(note).font(.system(size: 11)).foregroundStyle(.orange).padding(.leading, 96)
                }

                Divider()

                HStack(spacing: 12) {
                    Text("权限")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(trusted ? Color.green : Color.orange)
                    Text(trusted ? "辅助功能已授权" : "缺少辅助功能权限，快捷键与系统操作不会生效")
                        .font(.system(size: 12))
                    if !trusted {
                        Button("去授权") { Actions.requestAccessibility() }.controlSize(.small)
                    }
                    Button("重新检查") { trusted = Actions.isAccessibilityGranted() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }

                Divider()

                HStack(spacing: 12) {
                    Text("设备")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)

                    Toggle("触感反馈", isOn: Binding(
                        get: { link.hapticsEnabled ?? true },
                        set: { link.setHaptics($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)

                    Text("自动休眠")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)

                    Picker("", selection: Binding(
                        get: { link.sleepSeconds ?? 7200 },
                        set: { link.setSleepSeconds($0) }
                    )) {
                        Text("不休眠").tag(0)
                        Text("1 小时").tag(3600)
                        Text("2 小时").tag(7200)
                        Text("3 小时").tag(10800)
                        Text("4 小时").tag(14400)
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 110)

                    Spacer()
                }

                Text("触感与休眠时间写进设备本身，断电后仍然保留；未连接设备时不可改。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 96)

                Divider()

                HStack(spacing: 12) {
                    Text("关于")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Text("版本 \(UpdateChecker.currentVersion)")
                        .font(.system(size: 12))
                    Button("检查更新") {
                        UpdateChecker.check(userInitiated: true)
                    }
                    .controlSize(.small)
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Text("应用规则")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 84, alignment: .leading)
                        Text("切到指定 App 时自动套用对应配置")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("添加规则…") { addAppRule() }
                            .controlSize(.small)
                    }

                    if store.appRules.isEmpty {
                        Text("还没有规则：所有 App 都使用「默认」配置")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 96)
                    }

                    ForEach(store.appRules.keys.sorted(), id: \.self) { bundle in
                        HStack(spacing: 10) {
                            Image(systemName: "app")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(appDisplayName(bundle))
                                .font(.system(size: 12))
                                .frame(width: 190, alignment: .leading)
                                .lineLimit(1)
                            Picker("", selection: ruleBinding(bundle)) {
                                ForEach(store.profileNames, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .controlSize(.small)
                            .frame(width: 150)
                            Button {
                                store.removeRule(bundleID: bundle)
                            } label: {
                                Image(systemName: "trash").font(.system(size: 10))
                            }
                            .buttonStyle(.borderless)
                            Spacer()
                        }
                        .padding(.leading, 96)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Text("其他")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 84, alignment: .leading)
                    Button("打开日志") { NSWorkspace.shared.open(logURL) }.controlSize(.small)
                    Button("退出 App") { NSApp.terminate(nil) }.controlSize(.small)
                }

                Text(store.configPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(24)
        }
    }

    // MARK: 应用规则

    private func ruleBinding(_ bundle: String) -> Binding<String> {
        Binding(
            get: { store.appRules[bundle] ?? store.activeProfile },
            set: { store.setRule(bundleID: bundle, profile: $0) }
        )
    }

    private func appDisplayName(_ bundle: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundle
    }

    private func addAppRule() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "选择要绑定配置的应用"
        panel.prompt = "绑定"
        if panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url)?.bundleIdentifier {
            store.setRule(bundleID: bundle, profile: store.activeProfile)
        }
    }

    private var batterySymbol: String {
        guard let value = Int(link.batteryText.replacingOccurrences(of: "%", with: "")) else {
            return "battery.0"
        }
        switch value {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    // MARK: 快捷键录制

    private func startHotKeyRecording() {
        stopMonitor()
        recordingHotKey = true

        let apply: (NSEvent) -> Void = { event in
            if event.keyCode == 53 {
                KeyCapture.shared.stop()
                stopMonitor()
                recordingHotKey = false
                return
            }
            if event.isARepeat { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.carbonModifiers != 0 else { return }
            settings.hotKeyCode = event.keyCode
            settings.hotKeyCarbonModifiers = flags.carbonModifiers
            settings.hotKeyLabel = KeyLabel.describe(event)
            settings.hotKeyEnabled = true
            HotKeyCenter.shared.apply(settings: settings)
            KeyCapture.shared.stop()
            stopMonitor()
            recordingHotKey = false
        }

        if KeyCapture.shared.start() {
            KeyCapture.shared.onKey = apply
        } else {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
                apply(event)
                return nil
            }
        }
    }

    private func stopMonitor() {
        KeyCapture.shared.onKey = nil
        KeyCapture.shared.stop()
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
