//
//  CountdownOverlay.swift
//  Tertia
//
//  Time Attack start-of-round "3 / 2 / 1" overlay. Owned by `GameView`,
//  which drives the value via `runStartCountdown()`. The .id(value)
//  modifier ensures each digit gets a fresh transition rather than
//  cross-fading in place.
//

import SwiftUI

struct CountdownOverlay: View {
    let value: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    var body: some View {
        if let value {
            Text("\(value)")
                .font(.system(size: 140, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 200, height: 200)
                .background(Color.black.opacity(0.6), in: .circle)
                .shadow(color: .black.opacity(0.35), radius: 20, y: 8)
                .id(value)
                .transition(reduceMotion
                    ? .opacity
                    : .scale(scale: 1.5).combined(with: .opacity))
                .accessibilityLabel("Starting in \(value)")
        }
    }
}
