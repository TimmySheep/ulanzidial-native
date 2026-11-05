import SwiftUI

/// 液态玻璃样式：macOS 26 起用系统原生 glassEffect，老系统退回材质
extension View {
    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 14) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    func glassBar() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: Rectangle())
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
