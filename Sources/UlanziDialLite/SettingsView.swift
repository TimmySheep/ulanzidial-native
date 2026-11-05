import AppKit
import Carbon.HIToolbox
import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if selection == .general {
                generalPane
            } else {
                DeviceTopView(store: store, selection: $selection, editing: $editing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .underPageBackgroundColor).opacity(0.35))
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .onDisappear { stopMonitor() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = Actions.isAccessibilityGranted()
            loginEnabled = LoginItem.isEnabled
        }
    }

    // MARK: 顶栏

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Ulanzi Dial").font(.system(size: 17, weight: .semibold))

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

            Button {
                selection = selection == .general ? .control(.topLeft) : .general
                editing = nil
                if recordingHotKey { stopMonitor(); recordingHotKey = false }
            } label: {
                Label(selection == .general ? "返回按键" : "通用", systemImage: "gearshape")
                    .font(.system(size: 12))
            }
            .controlSize(.small)

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
    }

    // MARK: 通用

    private var generalPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { stopMonitor(); recordingHotKey = false; return nil }
            if event.isARepeat { return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.carbonModifiers != 0 else { return nil }
            settings.hotKeyCode = event.keyCode
            settings.hotKeyCarbonModifiers = flags.carbonModifiers
            settings.hotKeyLabel = KeyLabel.describe(event)
            settings.hotKeyEnabled = true
            HotKeyCenter.shared.apply(settings: settings)
            stopMonitor()
            recordingHotKey = false
            return nil
        }
    }

    private func stopMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}
