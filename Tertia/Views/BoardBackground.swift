//
//  BoardBackground.swift
//  Tertia
//
//  Created by Mark Martin on 4/29/26.
//

import SwiftUI

/// Warm paper-folio tint shared by the main tabs (Play, Stats, Settings).
/// Hides system scroll-content backgrounds so List/Form rows blend onto the tint.
private struct BoardBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(tint.ignoresSafeArea())
    }

    private var tint: Color {
        colorScheme == .dark
            ? Color(red: 0.075, green: 0.075, blue: 0.090)   // deep slate
            : Color(red: 0.955, green: 0.940, blue: 0.910)   // paper folio
    }
}

extension View {
    func boardBackground() -> some View {
        modifier(BoardBackgroundModifier())
    }
}
