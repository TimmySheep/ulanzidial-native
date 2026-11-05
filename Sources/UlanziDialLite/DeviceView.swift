import SwiftUI

/// 设备俯视图：机身居中，每个控件旁浮一个绑定标签；点击任意控件弹出编辑面板
struct DeviceTopView: View {
    @ObservedObject var store: BindingStore
    @Binding var selection: SettingsView.Selection
    @Binding var editing: Control?

    private func popoverBinding(_ control: Control) -> Binding<Bool> {
        Binding(
            get: { editing == control },
            set: { if !$0 { editing = nil } }
        )
    }

    private func arrowEdge(for control: Control) -> Edge {
        switch control {
        case .sideUpperLeft, .sideLowerLeft: return .leading
        case .sideUpperRight, .sideLowerRight: return .trailing
        default: return .top
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let bw = min(w * 0.46, h * 0.70)
            let bh = bw
            let cx = w * 0.5
            let cy = h * 0.52
            let x0 = cx - bw / 2
            let y0 = cy - bh / 2
            let chipW = min(96, max(62, bw * 0.175))

            ZStack {
                // 机身
                RoundedRectangle(cornerRadius: bw * 0.17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(nsColor: .windowBackgroundColor)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: bw * 0.17, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 18, y: 9)
                    .frame(width: bw, height: bh)
                    .position(x: cx, y: cy)

                // 顶部三键
                key(.topLeft, cx: x0 + bw * 0.30, cy: y0 + bh * 0.15, w: bw * 0.18, h: bh * 0.115)
                key(.topMiddle, cx: x0 + bw * 0.50, cy: y0 + bh * 0.15, w: bw * 0.18, h: bh * 0.115)
                key(.topRight, cx: x0 + bw * 0.70, cy: y0 + bh * 0.15, w: bw * 0.18, h: bh * 0.115)

                // 四个侧键
                key(.sideUpperLeft, cx: x0 + bw * 0.085, cy: y0 + bh * 0.37, w: bw * 0.085, h: bh * 0.135)
                key(.sideLowerLeft, cx: x0 + bw * 0.085, cy: y0 + bh * 0.64, w: bw * 0.085, h: bh * 0.135)
                key(.sideUpperRight, cx: x0 + bw * 0.915, cy: y0 + bh * 0.37, w: bw * 0.085, h: bh * 0.135)
                key(.sideLowerRight, cx: x0 + bw * 0.915, cy: y0 + bh * 0.64, w: bw * 0.085, h: bh * 0.135)

                // 旋钮：整块一个可点击区域
                knob(cx: cx, cy: cy + bh * 0.01, r: bw * 0.27)

                // 绑定标签
                chip(.topLeft, x: x0 + bw * 0.30, y: y0 - 20, width: chipW)
                chip(.topMiddle, x: x0 + bw * 0.50, y: y0 - 20, width: chipW)
                chip(.topRight, x: x0 + bw * 0.70, y: y0 - 20, width: chipW)

                chip(.sideUpperLeft, x: x0 - chipW / 2 - 14, y: y0 + bh * 0.37, width: chipW)
                chip(.sideLowerLeft, x: x0 - chipW / 2 - 14, y: y0 + bh * 0.64, width: chipW)
                chip(.sideUpperRight, x: x0 + bw + chipW / 2 + 14, y: y0 + bh * 0.37, width: chipW)
                chip(.sideLowerRight, x: x0 + bw + chipW / 2 + 14, y: y0 + bh * 0.64, width: chipW)

                chip(.knobClick, x: cx, y: cy + bw * 0.27 + 22, width: chipW + 6)
            }
        }
    }

    // MARK: 按键

    private func key(_ control: Control, cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let selected = isSelected(control)
        let bound = store.binding(control).kind != .none

        return RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.12) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(selected ? Color.accentColor.opacity(0.85) : Color.black.opacity(0.10),
                            lineWidth: selected ? 1.8 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if bound {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5).padding(5)
                }
            }
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .position(x: cx, y: cy)
            .onTapGesture { open(control) }
            .popover(isPresented: popoverBinding(control), arrowEdge: arrowEdge(for: control)) {
                ControlEditorCard(store: store, control: control) { editing = nil }
            }
            .help(control.name)
    }

    // MARK: 标签

    private func chip(_ control: Control, x: CGFloat, y: CGFloat, width: CGFloat) -> some View {
        let selected = isSelected(control)
        let text = store.binding(control).describe

        return Button {
            open(control)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: control == .knobClick ? "circle.dotted" : "square.text.square")
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                Text(text)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(selected ? Color.white : Color.primary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .frame(width: width)
            .glassCapsule()
            .overlay(Capsule().stroke(selected ? Color.accentColor : Color.white.opacity(0.45), lineWidth: selected ? 1.4 : 0.8))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .help(control.name)
    }

    // MARK: 旋钮

    private func knob(cx: CGFloat, cy: CGFloat, r: CGFloat) -> some View {
        let selected = isSelected(.knobClick)

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, Color(nsColor: .controlBackgroundColor)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 2,
                        endRadius: r * 1.5
                    )
                )
                .overlay(
                    Circle().stroke(selected ? Color.accentColor.opacity(0.85) : Color.black.opacity(0.08),
                                    lineWidth: selected ? 2 : 1)
                )
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)

            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
                .frame(width: r * 1.18, height: r * 1.18)

            VStack(spacing: 2) {
                Image(systemName: "dial.medium")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                Text("旋钮")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Circle())
        .onTapGesture { open(.knobClick) }
        .popover(isPresented: popoverBinding(.knobClick), arrowEdge: .top) {
            ControlEditorCard(store: store, control: .knobClick) { editing = nil }
        }
        .help("按下 / 旋转 / 按住旋转")
    }

    // MARK: 辅助

    private func isSelected(_ control: Control) -> Bool {
        selection == .control(control)
    }

    private func open(_ control: Control) {
        selection = .control(control)
        editing = control
    }
}
