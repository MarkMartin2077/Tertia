//
//  PointsToast.swift
//  Tertia
//
//  Brief "+N" capsule that flies in next to the score chip on every
//  scoring trio. Owns its own dismiss timer keyed on `id` so a fresh
//  trio mid-fade replaces the toast cleanly.
//

import SwiftUI

struct PointsToast: View {
    @Binding var value: Int?
    let id: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if let value {
            Text("+\(value)")
                .font(.title3.bold())
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.18), in: .capsule)
                .id(id)
                .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .leading).combined(with: .opacity))
                .accessibilityLabel("Plus \(value) points")
                .task(id: id) {
                    try? await Task.sleep(for: .milliseconds(900))
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.value = nil
                    }
                }
        }
    }
}
