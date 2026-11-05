import SwiftUI

/// 设备俯视图（参考官方布局）：机身居中，每个控件旁边浮一个标签显示当前绑定
struct DeviceTopView: View {
    @ObservedObject var store: BindingStore
    @Binding var selection: SettingsView.Selection
    @Binding var editing: Control?

    private let chipW: CGFloat = 104

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
            let bw = min(w * 0.44, h * 0.70)
            let bh = bw
            let cx = w * 0.5
            let cy = h * 0.50
            let x0 = cx - bw / 2
            let y0 = cy - bh / 2

            ZStack {
                // 机身
                RoundedRectangle(cornerRadius: bw * 0.16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(nsColor: .controlBackgroundColor), Color(nsColor: .windowBackgroundColor)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: bw * 0.16, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.85), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
                    .frame(width: bw, height: bh)
                    .position(x: cx, y: cy)

                // 顶部三键
                key(.topLeft, cx: x0 + bw * 0.30, cy: y0 + bh * 0.135, w: bw * 0.17, h: bh * 0.11)
                key(.topMiddle, cx: x0 + bw * 0.50, cy: y0 + bh * 0.135, w: bw * 0.17, h: bh * 0.11)
                key(.topRight, cx: x0 + bw * 0.70, cy: y0 + bh * 0.135, w: bw * 0.17, h: bh * 0.11)

                // 四个侧键
                key(.sideUpperLeft, cx: x0 + bw * 0.10, cy: y0 + bh * 0.36, w: bw * 0.085, h: bh * 0.13)
                key(.sideLowerLeft, cx: x0 + bw * 0.10, cy: y0 + bh * 0.66, w: bw * 0.085, h: bh * 0.13)
                key(.sideUpperRight, cx: x0 + bw * 0.90, cy: y0 + bh * 0.36, w: bw * 0.085, h: bh * 0.13)
                key(.sideLowerRight, cx: x0 + bw * 0.90, cy: y0 + bh * 0.66, w: bw * 0.085, h: bh * 0.13)

                // 旋钮
                knob(cx: cx, cy: cy, r: bw * 0.255)

                // 标签
                chip(.topLeft, x: x0 + bw * 0.30, y: y0 - 22)
                chip(.topMiddle, x: x0 + bw * 0.50, y: y0 - 22)
                chip(.topRight, x: x0 + bw * 0.70, y: y0 - 22)

                chip(.sideUpperLeft, x: x0 - chipW / 2 - 16, y: y0 + bh * 0.36)
                chip(.sideLowerLeft, x: x0 - chipW / 2 - 16, y: y0 + bh * 0.66)
                chip(.sideUpperRight, x: x0 + bw + chipW / 2 + 16, y: y0 + bh * 0.36)
                chip(.sideLowerRight, x: x0 + bw + chipW / 2 + 16, y: y0 + bh * 0.66)

                chip(.knobClick, x: cx, y: cy - bw * 0.255 - 18)
            }
        }
    }

    // MARK: 按键

    private func key(_ control: Control, cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        let selected = selection == .control(control)
        let bound = store.binding(control).kind != .none

        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selected ? Color.accentColor.opacity(0.16) : Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if bound {
                    Circle().fill(Color.accentColor).frame(width: 5, height: 5).padding(4)
                }
            }
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            .position(x: cx, y: cy)
            .onTapGesture { selection = .control(control); editing = control }
            .popover(isPresented: popoverBinding(control), arrowEdge: arrowEdge(for: control)) {
                ControlEditorCard(store: store, control: control) { editing = nil }
            }
            .help(control.name)
    }

    // MARK: 标签

    private func chip(_ control: Control, x: CGFloat, y: CGFloat) -> some View {
        let selected = selection == .control(control)
        let text = store.binding(control).describe

        return Button {
            selection = .control(control)
            editing = control
        } label: {
            HStack(spacing: 4) {
                Image(systemName: control == .knobClick ? "circle.circle" : "square.text.square")
                    .font(.system(size: 9))
                    .foregroundStyle(selected ? Color.white : Color.secondary)
                Text(text)
                    .font(.system(size: 10, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                    .foregroundStyle(selected ? Color.white : Color.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: chipW)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Color.accentColor : Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .position(x: x, y: y)
        .popover(isPresented: popoverBinding(control), arrowEdge: arrowEdge(for: control)) {
            ControlEditorCard(store: store, control: control) { editing = nil }
        }
        .help(control.name)
    }

    // MARK: 旋钮

    private func knob(cx: CGFloat, cy: CGFloat, r: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(nsColor: .textBackgroundColor), Color(nsColor: .controlBackgroundColor)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: r * 1.5
                    )
                )
                .overlay(Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

            ringButton(.rotateCCW, symbol: "chevron.left", x: cx - r - 15, y: cy, side: 24)
            ringButton(.rotateCW, symbol: "chevron.right", x: cx + r + 15, y: cy, side: 24)
            ringButton(.knobHoldCCW, symbol: "arrow.counterclockwise", x: cx - r * 0.58, y: cy, side: 20)
            ringButton(.knobHoldCW, symbol: "arrow.clockwise", x: cx + r * 0.58, y: cy, side: 20)

            // 中心按下
            Circle()
                .fill(selection == .control(.knobClick) ? Color.accentColor.opacity(0.18) : Color(nsColor: .windowBackgroundColor))
                .overlay(
                    Circle().stroke(
                        selection == .control(.knobClick) ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: selection == .control(.knobClick) ? 2 : 1
                    )
                )
                .overlay(Image(systemName: "circle.circle").font(.system(size: 10)).foregroundStyle(.secondary))
                .frame(width: r * 0.56, height: r * 0.56)
                .position(x: cx, y: cy)
                .onTapGesture { selection = .control(.knobClick); editing = .knobClick }
                .popover(isPresented: popoverBinding(.knobClick), arrowEdge: .top) {
                    ControlEditorCard(store: store, control: .knobClick) { editing = nil }
                }
        }
    }

    private func ringButton(_ control: Control, symbol: String, x: CGFloat, y: CGFloat, side: CGFloat) -> some View {
        let selected = selection == .control(control)
        let bound = store.binding(control).kind != .none

        return Circle()
            .fill(selected ? Color.accentColor : Color(nsColor: .textBackgroundColor))
            .overlay(Circle().stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Color.secondary)
            )
            .overlay(alignment: .topTrailing) {
                if bound && !selected {
                    Circle().fill(Color.accentColor).frame(width: 4, height: 4).padding(0.5)
                }
            }
            .frame(width: side, height: side)
            .position(x: x, y: y)
            .onTapGesture { selection = .control(control); editing = control }
            .popover(isPresented: popoverBinding(control), arrowEdge: arrowEdge(for: control)) {
                ControlEditorCard(store: store, control: control) { editing = nil }
            }
            .help(control.name)
    }
}
