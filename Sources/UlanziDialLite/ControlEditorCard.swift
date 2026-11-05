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
                Menu {
                    ForEach(knobSlots, id: \.self) { slot in
                        Button {
                            gesture = slot
                            recording = false
                            stopMonitor()
                        } label: {
                            if slot == active {
                                Label(gestureName(slot), systemImage: "checkmark")
                            } else {
                                Text(gestureName(slot))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("手势：\(gestureName(active))")
                            .font(.system(size: 12))
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
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
        .frame(width: 420)
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

        case .sequence:
            sequenceEditor
        }
    }

    // MARK: 多项操作编辑器

    @State private var recordingStep: Int?

    private var sequenceEditor: some View {
        let steps = store.binding(active).steps ?? []
        return VStack(alignment: .leading, spacing: 10) {
            if steps.isEmpty {
                Text("按顺序执行多个动作，每步可设等待时间")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.accentColor.opacity(0.15)))
                        stepTypeMenu(index: index, step: step)
                        Spacer()
                        TextField("", value: Binding(
                            get: { step.delayMs },
                            set: { newValue in
                                updateStep(index) { $0.delayMs = max(0, min(newValue, 60_000)) }
                            }
                        ), format: .number)
                        .frame(width: 54)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        Text("ms").font(.system(size: 10)).foregroundStyle(.secondary)
                        Button {
                            removeStep(index)
                        } label: {
                            Image(systemName: "trash").font(.system(size: 10))
                        }
                        .buttonStyle(.borderless)
                    }

                    stepEditor(index: index, step: step)
                        .padding(.leading, 22)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.6)))
            }

            Button {
                addStep()
            } label: {
                Label("添加步骤", systemImage: "plus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
        }
    }

    private func stepTypeMenu(index: Int, step: Step) -> some View {
        Menu {
            ForEach([ActionKind.key, .media, .text, .app, .url, .shell, .system]) { kind in
                Button {
                    updateStep(index) { $0.action.kind = kind }
                } label: {
                    Label(kind.name, systemImage: kind.symbol)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: step.action.kind.symbol).font(.system(size: 10))
                Text(step.action.kind.name).font(.system(size: 11))
                Image(systemName: "chevron.down").font(.system(size: 7)).foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private func stepEditor(index: Int, step: Step) -> some View {
        switch step.action.kind {
        case .key:
            Button {
                startRecordingStep(index)
            } label: {
                Text(recordingStep == index ? "请按一个键…" : (step.action.keyLabel ?? "点击录制"))
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .media:
            Picker("", selection: stepMediaBinding(index)) {
                ForEach(MediaKey.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden().controlSize(.small)

        case .text:
            TextField("要输入的文字", text: stepStringBinding(index, \.text))
                .textFieldStyle(.roundedBorder).font(.system(size: 11))

        case .app:
            Button(step.action.path.map { ($0 as NSString).lastPathComponent } ?? "选择 App…") {
                chooseAppForStep(index)
            }
            .controlSize(.small)

        case .url:
            TextField("网址或路径", text: stepStringBinding(index, \.url))
                .textFieldStyle(.roundedBorder).font(.system(size: 11))

        case .shell:
            TextField("命令", text: stepStringBinding(index, \.command))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11, design: .monospaced))

        case .system:
            Picker("", selection: stepSystemBinding(index)) {
                ForEach(SystemAction.allCases) { Text($0.name).tag($0) }
            }
            .labelsHidden().controlSize(.small)

        default:
            Text("选择该步的动作类型").font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private func addStep() {
        var action = store.binding(active)
        var steps = action.steps ?? []
        steps.append(Step())
        action.steps = steps
        action.kind = .sequence
        store.set(active, action)
    }

    private func removeStep(_ index: Int) {
        var action = store.binding(active)
        var steps = action.steps ?? []
        guard index < steps.count else { return }
        steps.remove(at: index)
        action.steps = steps
        store.set(active, action)
    }

    private func updateStep(_ index: Int, _ transform: (inout Step) -> Void) {
        var action = store.binding(active)
        var steps = action.steps ?? []
        guard index < steps.count else { return }
        transform(&steps[index])
        action.steps = steps
        store.set(active, action)
    }

    private func stepMediaBinding(_ index: Int) -> Binding<MediaKey> {
        Binding(
            get: {
                let steps = store.binding(active).steps ?? []
                let raw = index < steps.count ? (steps[index].action.media ?? "") : ""
                return MediaKey(rawValue: raw) ?? .volumeUp
            },
            set: { newValue in
                updateStep(index) { $0.action.kind = .media; $0.action.media = newValue.rawValue }
            }
        )
    }

    private func stepSystemBinding(_ index: Int) -> Binding<SystemAction> {
        Binding(
            get: {
                let steps = store.binding(active).steps ?? []
                let raw = index < steps.count ? (steps[index].action.system ?? "") : ""
                return SystemAction(rawValue: raw) ?? .lockScreen
            },
            set: { newValue in
                updateStep(index) { $0.action.kind = .system; $0.action.system = newValue.rawValue }
            }
        )
    }

    private func stepStringBinding(_ index: Int, _ keyPath: WritableKeyPath<Action, String?>) -> Binding<String> {
        Binding(
            get: {
                let steps = store.binding(active).steps ?? []
                return index < steps.count ? (steps[index].action[keyPath: keyPath] ?? "") : ""
            },
            set: { newValue in
                updateStep(index) { $0.action[keyPath: keyPath] = newValue }
            }
        )
    }

    private func chooseAppForStep(_ index: Int) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            updateStep(index) { $0.action.kind = .app; $0.action.path = url.path }
        }
    }

    private func startRecordingStep(_ index: Int) {
        stopMonitor()
        recordingStep = index

        let apply: (NSEvent) -> Void = { event in
            if event.keyCode == 53 {
                KeyCapture.shared.stop()
                stopMonitor()
                recordingStep = nil
                return
            }
            if event.isARepeat { return }
            updateStep(index) {
                $0.action.kind = .key
                $0.action.keyCode = event.keyCode
                $0.action.modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
                $0.action.keyLabel = KeyLabel.describe(event)
            }
            KeyCapture.shared.stop()
            stopMonitor()
            recordingStep = nil
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

        let apply: (NSEvent) -> Void = { event in
            if event.keyCode == 53 {
                KeyCapture.shared.stop()
                stopMonitor()
                recording = false
                return
            }
            if event.isARepeat { return }
            var action = store.binding(target)
            action.kind = .key
            action.keyCode = event.keyCode
            action.modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
            action.keyLabel = KeyLabel.describe(event)
            store.set(target, action)
            KeyCapture.shared.stop()
            stopMonitor()
            recording = false
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
