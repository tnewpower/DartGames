//
//  ActiveHighlight.swift
//  Dart Games
//
//  Created by Tony Newpower on 8/18/25.
//


import SwiftUI

struct ActiveHighlight: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor)           // pass a ShapeStyle
                    .opacity(active ? 0.18 : 0.0)      // then fade the view
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor, lineWidth: 1)
                    .opacity(active ? 1.0 : 0.0)       // show border only when active
            )
            .shadow(
                color: Color.accentColor.opacity(active ? 0.25 : 0.0),
                radius: active ? 6 : 0, x: 0, y: 0
            )
    }
}

extension View {
    func activeHighlight(_ active: Bool) -> some View {
        modifier(ActiveHighlight(active: active))
    }
}

