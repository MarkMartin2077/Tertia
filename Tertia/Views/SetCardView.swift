//
//  SetCardView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let card: SetCard
    let isSelected: Bool
    let isInvalid: Bool
    var pulsingAttributes: Set<CardAttribute> = []
    var pulseToken: Int = 0
    var isHaloed: Bool = false
    var haloPulseToken: Int = 0
    let action: () -> Void

    @State private var haloBreath: Bool = false

    private static let cornerRadius: CGFloat = 14

    private var pulsesShape: Bool {
        !pulsingAttributes.isDisjoint(with: [.shape, .count, .fill])
    }

    private var pulsesColor: Bool {
        pulsingAttributes.contains(.color)
    }

    /// Halo only renders when the card isn't already in a selection or invalid state.
    private var showsHalo: Bool {
        isHaloed && !isSelected && !isInvalid
    }

    private var haloOpacity: Double {
        guard showsHalo else { return 0 }
        if reduceMotion { return 0.5 }
        return haloBreath ? 0.7 : 0.3
    }

    var body: some View {
        Button(action: action) {
            SetCardLayoutView(
                card: card,
                pulsesShape: pulsesShape,
                pulsesColor: pulsesColor,
                pulseToken: pulseToken
            )
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(cardFace)
                .overlay { topGleam.allowsHitTesting(false) }
                .overlay {
                    // Hairline printed edge — only when no other emphasis applies
                    if !isSelected && !isInvalid && !showsHalo {
                        RoundedRectangle(cornerRadius: Self.cornerRadius)
                            .strokeBorder(hairlineColor, lineWidth: 0.5)
                    }
                }
                .overlay {
                    // Slow-glow practice halo — passive teaching cue
                    if showsHalo {
                        RoundedRectangle(cornerRadius: Self.cornerRadius)
                            .strokeBorder(.orange, lineWidth: 2)
                            .opacity(haloOpacity)
                    }
                }
                .overlay {
                    // Selection / invalid border sits on top
                    if isSelected || isInvalid {
                        RoundedRectangle(cornerRadius: Self.cornerRadius)
                            .strokeBorder(emphasisBorderColor, lineWidth: 3)
                    }
                }
                .clipShape(.rect(cornerRadius: Self.cornerRadius))
                // Always-on contact shadow — card resting on the board
                .shadow(color: contactShadowColor, radius: 6, x: 0, y: 3)
                // Halo glow when active (no selection)
                .shadow(
                    color: showsHalo ? .orange.opacity(0.4 * haloOpacity) : .clear,
                    radius: 12
                )
                // Selection / invalid glow stacks below the contact shadow
                .shadow(color: emphasisShadowColor, radius: emphasisShadowRadius)
        }
        .id(card.id)
        .onChange(of: showsHalo) { _, isOn in
            if isOn && !reduceMotion {
                haloBreath = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    haloBreath = true
                }
            } else {
                haloBreath = false
            }
        }
        .onChange(of: haloPulseToken) { _, _ in
            // Re-trigger the breath animation when the hint resets to a new pair.
            guard showsHalo, !reduceMotion else { return }
            haloBreath = false
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                haloBreath = true
            }
        }
        .onAppear {
            guard showsHalo, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                haloBreath = true
            }
        }
    }

    // MARK: - Card face

    private var cardFace: some View {
        LinearGradient(
            colors: [cardFaceTop, cardFaceBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var cardFaceTop: Color {
        colorScheme == .dark
            ? Color(red: 0.165, green: 0.165, blue: 0.180)   // warm slate
            : Color(red: 1.000, green: 0.997, blue: 0.988)   // ivory
    }

    private var cardFaceBottom: Color {
        colorScheme == .dark
            ? Color(red: 0.120, green: 0.120, blue: 0.135)
            : Color(red: 0.985, green: 0.975, blue: 0.955)   // warm cream
    }

    private var topGleam: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.04 : 0.35),
                .clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    // MARK: - Borders

    private var hairlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.20)
    }

    private var emphasisBorderColor: Color {
        if isInvalid { return .red }
        if isSelected { return .yellow }
        return .clear
    }

    // MARK: - Shadows

    private var contactShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.50 : 0.13)
    }

    private var emphasisShadowColor: Color {
        if isInvalid { return .red.opacity(0.7) }
        if isSelected { return .yellow.opacity(0.7) }
        return .clear
    }

    private var emphasisShadowRadius: CGFloat {
        (isSelected || isInvalid) ? 8 : 0
    }
}

#Preview {
    SetCardView(card: .example, isSelected: false, isInvalid: false) { }
}
