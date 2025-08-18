import SwiftUI

struct ActiveHighlight: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? Color.tint.opacity(0.18) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? Color.tint : .clear, lineWidth: 1)
            )
            .shadow(color: active ? Color.tint.opacity(0.25) : .clear,
                    radius: active ? 6 : 0, x: 0, y: 0)
    }
}

extension View {
    func activeHighlight(_ active: Bool) -> some View { modifier(ActiveHighlight(active: active)) }
}
