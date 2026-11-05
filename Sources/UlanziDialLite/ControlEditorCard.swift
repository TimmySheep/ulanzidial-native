import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 点击设备上某个控件后弹出的编辑卡片
struct ControlEditorCard: View {
    @ObservedObject var store: BindingStore
    let control: Control
    var onClose: () -> Void

    @State private var gesture: Control?
    @State private var recording = false
    @State private var monitor: Any?

    private let knobSlots: [Control] = [.knobClick, .rotateCW, .rotateCCW, .knobHoldCW, .knobHoldCCW]

    private var isKnob: Bool { knobSlots.contains(control) }
    private var active: Control { gesture ?? control }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if isKnob {
                Picker("", selection: Binding(
                    get: { active },
                    set: { gesture = $0; recording = false; stopMonitor() }
                )) {
                    ForEach(knobSlots, id: \.self) { slot in
                        Text(gestureName(slot)).tag(slot)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Divider()

            typeMenu
            editor

            HStack(spacing: 8) {
                Button {
                    Actions.perform(store.binding(active))
                    logLine("TEST \(active.name) -> \(store.binding(active).describe)")
                } label: {
                    Label("试一下", systemImage: "play.circle")
                }
                .controlSize(.small)
                .disabled(store.binding(active).kind == .none)

                Button("清除") {
                    store.set(active, .empty)
                }
                .controlSize(.small)
                .disabled(store.binding(active).kind == .none)

                Spacer()

                Button("完成") { onClose() }
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onDisappear { stopMonitor() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: isKnob ? "circle.circle" : "square.text.square")
                .foregroundStyle(Color.accentColor)
            Text(control.name).font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(store.binding(active).kind.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var typeMenu: some View {
        Menu {
            ForEach(ActionKind.allCases) { kind in
                Button {
                    var action = store.binding(active)
                    action.kind = kind
                    store.set(active, action)
                    if kind == .key, action.keyCode == nil { startRecording() }
                    if kind == .media, action.media == nil {
                        action.media = MediaKey.volumeUp.rawValue
                        store.set(active, action)
                    }
                    if kind == .system, action.system == nil {
                        action.system = SystemAction.lockScreen.rawValue
                        store.set(active, action)
                    }
                } label: {
                    Label(kind.name, systemImage: kind.symbol)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: store.binding(active).kind.symbol).font(.system(size: 11))
                Text(store.binding(active).kind.name).font(.system(size: 12))
                Spacer()
                Image(systemName: "chevron.down").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    @ViewBuilder
    private var editor: some View {
        switch store.binding(active).kind {
        case .none:
            Text("选择一个动作类型开始设置")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

        case .key:
            Button {
                startRecording()
            } label: {
                Text(recording ? "请按一个键…（Esc 取消）" : (store.binding(active).keyLabel ?? "点击后按键盘"))
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)

        case .media:
            Picker("", selection: mediaBinding) {
                ForEach(MediaKey.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden()

        case .text:
            TextField("要输入的文字", text: stringBinding(\.text))
                .textFieldStyle(.roundedBorder)

        case .app:
            HStack(spacing: 8) {
                Text(store.binding(active).path.map { ($0 as NSString).lastPathComponent } ?? "未选择")
                    .font(.system(size: 12))
                    .foregroundStyle(store.binding(active).path == nil ? .secondary : .primary)
                    .lineLimit(1)
                Spacer()
                Button("选择 App…") { chooseApp() }.controlSize(.small)
            }

        case .url:
            TextField("https://… 或文件路径", text: stringBinding(\.url))
                .textFieldStyle(.roundedBorder)

        case .shell:
            TextField("例如 open -a Notes", text: stringBinding(\.command))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))

        case .system:
            Picker("", selection: systemBinding) {
                ForEach(SystemAction.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden()
        }
    }

    private func gestureName(_ control: Control) -> String {
        switch control {
        case .knobClick: return "按下"
        case .rotateCW: return "右旋"
        case .rotateCCW: return "左旋"
        case .knobHoldCW: return "按住右旋"
        case .knobHoldCCW: return "按住左旋"
        default: return control.name
        }
    }

    // MARK: 绑定

    private var mediaBinding: Binding<MediaKey> {
        Binding(
            get: { MediaKey(rawValue: store.binding(active).media ?? "") ?? .volumeUp },
            set: { newValue in
                var action = store.binding(active)
                action.kind = .media
                action.media = newValue.rawValue
                store.set(active, action)
            }
        )
    }

    private var systemBinding: Binding<SystemAction> {
        Binding(
            get: { SystemAction(rawValue: store.binding(active).system ?? "") ?? .lockScreen },
            set: { newValue in
                var action = store.binding(active)
                action.kind = .system
                action.system = newValue.rawValue
                store.set(active, action)
            }
        )
    }

    private func stringBinding(_ keyPath: WritableKeyPath<Action, String?>) -> Binding<String> {
        Binding(
            get: { store.binding(active)[keyPath: keyPath] ?? "" },
            set: { newValue in
                var action = store.binding(active)
                action[keyPath: keyPath] = newValue
                store.set(active, action)
            }
        )
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            var action = store.binding(active)
            action.kind = .app
            action.path = url.path
            store.set(active, action)
        }
    }

    private func startRecording() {
        stopMonitor()
        recording = true
        let target = active
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { stopMonitor(); recording = false; return nil }
            if event.isARepeat { return nil }
            var action = store.binding(target)
            action.kind = .key
            action.keyCode = event.keyCode
            action.modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            action.keyLabel = KeyLabel.describe(event)
            store.set(target, action)
            stopMonitor()
            recording = false
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
