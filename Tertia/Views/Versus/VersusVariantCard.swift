//
//  VersusVariantCard.swift
//  Tertia
//
//  Single radio-style card for the versus variant picker. Tapping selects
//  the variant; visual state (filled radio + accent stroke + slight scale)
//  reflects whether this card is the current pick.
//
//  Stats blurb (right-aligned, caption) is filled in by the parent so
//  this view stays presentation-only — no store dependencies.
//

import SwiftUI

struct VersusVariantCard: View {
    let variant: VersusVariant
    let title: String
    let description: String
    let glyph: String
    let accent: Color
    let isSelected: Bool
    /// Right-aligned caption text (e.g., "12-8 W-L" or "—"). Optional —
    /// pass nil to omit the stat row.
    let statBlurb: String?
    /// Whether to render the small "new" badge in the title row. Driven
    /// by a UserDefaults "seen-at" flag in the parent.
    let showsNewBadge: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                radioDot
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title)
                            .font(.headline.weight(.heavy))
                            .tracking(1.2)
                            .foregroundStyle(.primary)
                        if showsNewBadge {
                            Text("NEW")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accent, in: .capsule)
                                .accessibilityLabel("New mode")
                        }
                        Spacer()
                        if let statBlurb {
                            Text(statBlurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: glyph)
                        .font(.title3)
                        .foregroundStyle(accent.opacity(0.55))
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardStroke)
            .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1.0)
            .shadow(
                color: isSelected ? accent.opacity(0.18) : .clear,
                radius: 14,
                y: 6
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var radioDot: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accent : Color.secondary.opacity(0.4), lineWidth: 2)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.top, 2)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(isSelected ? accent.opacity(0.12) : Color.secondary.opacity(0.08))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(
                isSelected ? accent.opacity(0.55) : Color.secondary.opacity(0.2),
                lineWidth: isSelected ? 1.5 : 1
            )
    }

    private var accessibilitySummary: String {
        var parts = [title]
        if showsNewBadge {
            parts.append("New mode")
        }
        parts.append(description)
        if let statBlurb {
            parts.append(statBlurb)
        }
        return parts.joined(separator: ". ")
    }
}

#Preview("Selected") {
    VersusVariantCard(
        variant: .normal,
        title: "NORMAL",
        description: "Race for the highest score. No clock. Ends when the deck runs out.",
        glyph: "infinity",
        accent: .teal,
        isSelected: true,
        statBlurb: "12-8 W-L",
        showsNewBadge: false,
        onTap: {}
    )
    .padding()
}

#Preview("Unselected with New badge") {
    VersusVariantCard(
        variant: .firstTo10,
        title: "FIRST TO 10",
        description: "First player to claim 10 trios wins. Fast-paced races.",
        glyph: "10.circle.fill",
        accent: .orange,
        isSelected: false,
        statBlurb: "—",
        showsNewBadge: true,
        onTap: {}
    )
    .padding()
}
