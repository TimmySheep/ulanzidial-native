import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: BindingStore
    let link: DialLink

    @State private var recording: Control?
    @State private var monitor: Any?
    @State private var trusted = Actions.isAccessibilityGranted()
    @State private var loginEnabled = LoginItem.isEnabled
    @State private var loginNote: String?
    @State private var tick = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("顶部三键", subtitle: "设备正面朝上，从左到右", controls: Control.topRow)
                    section("侧键", subtitle: "左侧上/下、右侧上/下", controls: Control.sideRow)
                    section("旋钮", subtitle: "旋转每转一格触发一次；按住旋转可单独绑定", controls: Control.knobGroup)
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 760, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { refreshState() }
        .onDisappear { stopMonitor() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            trusted = Actions.isAccessibilityGranted()
            loginEnabled = LoginItem.isEnabled
            tick += 1
        }
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "dial.medium")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(link.isOnline ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("Ulanzi Dial Lite").font(.title3.weight(.semibold))
                HStack(spacing: 10) {
                    Label(link.stateText, systemImage: link.isOnline ? "dot.radiowaves.left.and.right" : "bolt.horizontal.circle")
                        .foregroundStyle(link.isOnline ? Color.green : Color.secondary)
                    Text("电量 \(link.batteryText)").foregroundStyle(.secondary)
                }
                .font(.callout)
            }

            Spacer()

            Button {
                link.reconnect()
            } label: {
                Label("重新连接", systemImage: "arrow.triangle.2.circlepath")
            }
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: 分组

    private func section(_ title: String, subtitle: String, controls: [Control]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(controls.enumerated()), id: \.element) { index, control in
                    row(control)
                    if index != controls.count - 1 {
                        Divider().padding(.leading, 34)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
        }
    }

    private func row(_ control: Control) -> some View {
        HStack(spacing: 12) {
            Image(systemName: control.symbol)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(control.name).font(.system(size: 13))
                Text(control.hint).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            .frame(width: 150, alignment: .leading)

            typeMenu(control)
                .frame(width: 132, alignment: .leading)

            editor(control)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                store.set(control, .empty)
                if recording == control { stopMonitor(); recording = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(store.binding(control).kind == .none ? Color.secondary.opacity(0.3) : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("清除此槽位")
            .disabled(store.binding(control).kind == .none)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func typeMenu(_ control: Control) -> some View {
        let kind = store.binding(control).kind
        return Menu {
            ForEach(ActionKind.allCases) { candidate in
                Button {
                    var action = store.binding(control)
                    action.kind = candidate
                    store.set(control, action)
                    if candidate == .key, action.keyCode == nil { startRecording(control) }
                    if candidate == .media, action.media == nil { action.media = MediaKey.volumeUp.rawValue; store.set(control, action) }
                    if candidate == .system, action.system == nil { action.system = SystemAction.lockScreen.rawValue; store.set(control, action) }
                } label: {
                    Label(candidate.name, systemImage: candidate.symbol)
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: kind.symbol).font(.system(size: 11))
                Text(kind.name).font(.system(size: 12))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 128)
    }

    // MARK: 编辑器

    @ViewBuilder
    private func editor(_ control: Control) -> some View {
        switch store.binding(control).kind {
        case .none:
            Text("—").foregroundStyle(.secondary).font(.system(size: 12))

        case .key:
            Button {
                startRecording(control)
            } label: {
                Text(recording == control ? "请按一个键…（Esc 取消）" : (store.binding(control).keyLabel ?? "点击后按键盘"))
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .media:
            Picker("", selection: mediaBinding(control)) {
                ForEach(MediaKey.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden()
            .controlSize(.small)

        case .text:
            TextField("要输入的文字", text: stringBinding(control, \.text))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

        case .app:
            HStack(spacing: 6) {
                Text(store.binding(control).path.map { ($0 as NSString).lastPathComponent } ?? "未选择")
                    .font(.system(size: 12))
                    .foregroundStyle(store.binding(control).path == nil ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                Button("选择 App…") { chooseApp(control) }
                    .controlSize(.small)
            }

        case .url:
            TextField("https://… 或文件路径", text: stringBinding(control, \.url))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

        case .shell:
            TextField("例如 open -a Notes", text: stringBinding(control, \.command))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

        case .system:
            Picker("", selection: systemBinding(control)) {
                ForEach(SystemAction.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden()
            .controlSize(.small)
        }
    }

    // MARK: 底部

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(trusted ? Color.green : Color.orange)
                Text(trusted ? "辅助功能权限已授予" : "缺少「辅助功能」权限，快捷键/文字/系统操作不会生效")
                    .font(.system(size: 12))
                if !trusted {
                    Button("去授权") { Actions.requestAccessibility() }.controlSize(.small)
                }
                Spacer()
                Button("重新检查") { refreshState() }
                    .controlSize(.small)
                    .buttonStyle(.link)
            }

            HStack(spacing: 10) {
                Toggle("开机时自动启动", isOn: Binding(
                    get: { loginEnabled },
                    set: { newValue in
                        if let error = LoginItem.setEnabled(newValue) {
                            loginNote = "设置失败：\(error)"
                        } else {
                            loginNote = newValue && !LoginItem.isEnabled ? "已提交，等待系统批准" : nil
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
                Spacer()
            }

            if let note = loginNote {
                Text(note).font(.system(size: 11)).foregroundStyle(.orange)
            }

            HStack(spacing: 6) {
                Text("配置文件").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(store.configPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("打开日志") { NSWorkspace.shared.open(logURL) }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .underPageBackgroundColor).opacity(0.5))
    }

    // MARK: 绑定

    private func refreshState() {
        trusted = Actions.isAccessibilityGranted()
        loginEnabled = LoginItem.isEnabled
    }

    private func kindBinding(_ control: Control) -> Binding<ActionKind> {
        Binding(
            get: { store.binding(control).kind },
            set: { newKind in
                var action = store.binding(control)
                action.kind = newKind
                store.set(control, action)
            }
        )
    }

    private func mediaBinding(_ control: Control) -> Binding<MediaKey> {
        Binding(
            get: { MediaKey(rawValue: store.binding(control).media ?? "") ?? .volumeUp },
            set: { newValue in
                var action = store.binding(control)
                action.kind = .media
                action.media = newValue.rawValue
                store.set(control, action)
            }
        )
    }

    private func systemBinding(_ control: Control) -> Binding<SystemAction> {
        Binding(
            get: { SystemAction(rawValue: store.binding(control).system ?? "") ?? .lockScreen },
            set: { newValue in
                var action = store.binding(control)
                action.kind = .system
                action.system = newValue.rawValue
                store.set(control, action)
            }
        )
    }

    private func stringBinding(_ control: Control, _ keyPath: WritableKeyPath<Action, String?>) -> Binding<String> {
        Binding(
            get: { store.binding(control)[keyPath: keyPath] ?? "" },
            set: { newValue in
                var action = store.binding(control)
                action[keyPath: keyPath] = newValue
                store.set(control, action)
            }
        )
    }

    // MARK: 交互

    private func chooseApp(_ control: Control) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            var action = store.binding(control)
            action.kind = .app
            action.path = url.path
            store.set(control, action)
            logLine("bind \(control.name) -> app \(url.path)")
        }
    }

    private func startRecording(_ control: Control) {
        stopMonitor()
        recording = control
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Esc
                stopMonitor()
                recording = nil
                return nil
            }
            if event.isARepeat { return nil }
            var action = store.binding(control)
            action.kind = .key
            action.keyCode = event.keyCode
            action.modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            action.keyLabel = KeyLabel.describe(event)
            store.set(control, action)
            logLine("bind \(control.name) -> \(action.keyLabel ?? "?")")
            stopMonitor()
            recording = nil
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
