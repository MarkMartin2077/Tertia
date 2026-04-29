//
//  SetSymbolView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

private struct PulseValues {
    var scale: CGFloat
    var opacity: Double
}

struct SetSymbolView: View {
    let card: SetCard
    var symbolSize: Double = 32
    var pulsesShape: Bool = false
    var pulsesColor: Bool = false
    var pulseToken: Int = 0

    var body: some View {
        Image(systemName: card.shape.systemName(for: card.fill))
            .frame(width: symbolSize, height: symbolSize)
            .font(.system(size: symbolSize))
            .foregroundStyle(card.color.color)
            .keyframeAnimator(
                initialValue: PulseValues(scale: 1.0, opacity: 1.0),
                trigger: pulseToken
            ) { content, value in
                content
                    .scaleEffect(value.scale)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    if pulsesShape {
                        CubicKeyframe(1.08, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.18)
                        CubicKeyframe(1.08, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.18)
                    } else {
                        LinearKeyframe(1.0, duration: 0.72)
                    }
                }
                KeyframeTrack(\.opacity) {
                    if pulsesColor {
                        CubicKeyframe(0.4, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.18)
                        CubicKeyframe(0.4, duration: 0.18)
                        CubicKeyframe(1.0, duration: 0.18)
                    } else {
                        LinearKeyframe(1.0, duration: 0.72)
                    }
                }
            }
    }
}

#Preview {
    SetSymbolView(card: .example)
}
