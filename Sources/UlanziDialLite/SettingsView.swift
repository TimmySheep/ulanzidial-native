import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BindingStore
    let link: DialLink

    @State private var recording: Control?
    @State private var monitor: Any?
    @State private var trusted = Actions.isAccessibilityGranted()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Control.ordered, id: \.self) { control in
                        row(control)
                        Divider()
                    }
                }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(minWidth: 660, minHeight: 620)
        .onAppear { trusted = Actions.isAccessibilityGranted() }
        .onDisappear { stopMonitor() }
    }

    // MARK: - 片段

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: link.isOnline ? "dot.radiowaves.left.and.right" : "bolt.slash")
                .foregroundColor(link.isOnline ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ulanzi Dial Lite").font(.headline)
                Text("设备状态：\(link.stateText)　电量：\(link.batteryText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("重新连接") { link.reconnect() }
                .controlSize(.small)
        }
    }

    private func row(_ control: Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(control.name).font(.body)
                Text(control.hint).font(.caption2).foregroundColor(.secondary)
            }
            .frame(width: 170, alignment: .leading)

            Picker("", selection: kindBinding(control)) {
                Text("无").tag(ActionKind.none)
                Text("快捷键").tag(ActionKind.key)
                Text("媒体键").tag(ActionKind.media)
            }
            .labelsHidden()
            .frame(width: 110)

            Group {
                switch store.binding(control).kind {
                case .none:
                    Text("—").foregroundColor(.secondary)
                case .key:
                    Button {
                        startRecording(control)
                    } label: {
                        Text(recording == control ? "请按一个键…（Esc 取消）" : (store.binding(control).keyLabel ?? "点击录制"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                case .media:
                    Picker("", selection: mediaBinding(control)) {
                        ForEach(MediaKey.allCases) { key in
                            Text(key.name).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: 280, alignment: .leading)

            Button {
                store.set(control, .empty)
                if recording == control { stopMonitor(); recording = nil }
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("清除此槽位")
            .disabled(store.binding(control).kind == .none)
        }
        .padding(.vertical, 7)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: trusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(trusted ? .green : .orange)
                Text(trusted ? "辅助功能权限已授予，可以模拟按键" : "缺少「辅助功能」权限，快捷键不会生效")
                    .font(.callout)
                if !trusted {
                    Button("去授权") { Actions.requestAccessibility() }
                        .controlSize(.small)
                }
                Button("重新检查") { trusted = Actions.isAccessibilityGranted() }
                    .controlSize(.small)
                    .buttonStyle(.link)
            }
            Text("改动即时生效并写入：\(store.configPath)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }

    // MARK: - 绑定

    private func kindBinding(_ control: Control) -> Binding<ActionKind> {
        Binding(
            get: { store.binding(control).kind },
            set: { newKind in
                var action = store.binding(control)
                action.kind = newKind
                store.set(control, action)
                if newKind == .key, action.keyCode == nil {
                    startRecording(control)
                }
            }
        )
    }

    private func mediaBinding(_ control: Control) -> Binding<MediaKey> {
        Binding(
            get: {
                MediaKey(rawValue: store.binding(control).media ?? "") ?? .volumeUp
            },
            set: { newValue in
                var action = store.binding(control)
                action.kind = .media
                action.media = newValue.rawValue
                store.set(control, action)
            }
        )
    }

    // MARK: - 录制快捷键

    private func startRecording(_ control: Control) {
        stopMonitor()
        recording = control
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 { // Esc 取消
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
