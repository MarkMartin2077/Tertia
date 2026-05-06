//
//  VersusVariantCard.swift
//  Tertia
//
//  Compact list-style row for the versus variant picker. Progressive
//  disclosure: every row shows glyph + title + 1-line tagline; the
//  selected row expands inline to reveal the full description and stat
//  blurb. One detail panel on screen at a time keeps the cognitive load
//  on what the user just chose, not what they could compare against.
//

import SwiftUI

struct VersusVariantCard: View {
    let variant: VersusVariant
    let title: String
    /// Always-visible one-liner. Lets the player scan modes without
    /// having to select each one.
    let tagline: String
    /// Longer description revealed only when this card is selected.
    let description: String
    let glyph: String
    let accent: Color
    let isSelected: Bool
    /// Right-aligned caption inside the expanded panel (e.g., "12-8 W-L").
    /// Optional — pass nil when the player has no history for this variant.
    let statBlurb: String?
    /// Whether to render the small "NEW" badge next to the title.
    let showsNewBadge: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                if isSelected {
                    detailPanel
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardStroke)
            .shadow(
                color: isSelected ? accent.opacity(0.18) : .clear,
                radius: 14,
                y: 6
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Header (always visible)

    private var headerRow: some View {
        HStack(spacing: 14) {
            Image(systemName: glyph)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
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
                }
                Text(tagline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            radioDot
        }
    }

    // MARK: - Expanded detail (selected only)

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.top, 12)
                .padding(.bottom, 4)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if let statBlurb {
                HStack {
                    Spacer()
                    Text(statBlurb)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        // Indent past the glyph column so the description hangs under
        // the title rather than starting flush with the icon.
        .padding(.leading, 42)
    }

    // MARK: - Radio

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
    }

    // MARK: - Backgrounds

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? accent.opacity(0.10) : Color.secondary.opacity(0.06))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isSelected ? accent.opacity(0.5) : Color.secondary.opacity(0.18),
                lineWidth: isSelected ? 1.5 : 1
            )
    }

    private var accessibilitySummary: String {
        var parts = [title]
        if showsNewBadge { parts.append("New mode") }
        // Use the full description for accessibility regardless of
        // selection — VoiceOver users shouldn't have to "select to read."
        parts.append(description)
        if let statBlurb { parts.append(statBlurb) }
        return parts.joined(separator: ". ")
    }
}

#Preview("Selected") {
    VersusVariantCard(
        variant: .firstTo10,
        title: "FIRST TO 10",
        tagline: "Sprint to 10 trios",
        description: "First player to claim 10 trios wins. Fast-paced races where every claim shifts the lead.",
        glyph: "10.circle.fill",
        accent: .orange,
        isSelected: true,
        statBlurb: "best 1:42",
        showsNewBadge: true,
        onTap: {}
    )
    .padding()
}

#Preview("Unselected") {
    VersusVariantCard(
        variant: .coop,
        title: "CO-OP",
        tagline: "Work through the deck together",
        description: "Team up. Work through the deck together — no winner, just speed and accuracy.",
        glyph: "person.2.fill",
        accent: .teal,
        isSelected: false,
        statBlurb: nil,
        showsNewBadge: true,
        onTap: {}
    )
    .padding()
}
