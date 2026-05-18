//
//  TutorialVerdictCard.swift
//  Tertia
//
//  Created by Mark Martin on 5/17/26.
//

import SwiftUI

/// Visual verdict panel shown in tutorial mode. Replaces the text-heavy
/// `PracticeVerdictBar` with a matrix that mirrors the actual attribute values
/// on the selected cards — new players can map "Shape: all different" back to
/// the triangle / circle / square they tapped without translation.
///
/// Always requires an explicit "Got it" tap; tutorial pacing relies on the
/// learner finishing reading before the next puzzle slides in.
struct TutorialVerdictCard: View {
    let cards: [SetCard]
    let explanation: SetExplanation
    let onDismiss: () -> Void

    private static let cornerRadius: CGFloat = 16
    private static let miniCardWidth: CGFloat = 44
    private static let miniCardHeight: CGFloat = 58
    private static let labelWidth: CGFloat = 56
    private static let glyphWidth: CGFloat = 24

    var body: some View {
        VStack(spacing: 8) {
            header
            miniCardsRow
            attributeMatrix
            dismissButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: Self.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(borderColor.opacity(0.5), lineWidth: 2)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: explanation.isSet ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(explanation.isSet ? .green : .red)
            Text(explanation.isSet ? "It's a trio!" : "Not a trio")
                .font(.headline)
                .foregroundStyle(headerTextColor)
            Spacer(minLength: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(explanation.isSet ? "Valid trio" : "Not a trio")
    }

    private var headerTextColor: Color {
        explanation.isSet ? GameMode.tutorial.accentColor : .red
    }

    private var borderColor: Color {
        explanation.isSet ? .green : .red
    }

    // MARK: - Mini cards

    private var miniCardsRow: some View {
        HStack(spacing: 8) {
            ForEach(cards) { card in
                MiniCardThumbnail(card: card)
                    .frame(width: Self.miniCardWidth, height: Self.miniCardHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - Attribute matrix

    private var attributeMatrix: some View {
        VStack(spacing: 1) {
            ForEach(CardAttribute.allCases) { attribute in
                AttributeRow(
                    attribute: attribute,
                    cards: cards,
                    outcome: explanation.outcome(for: attribute) ?? .mixed,
                    labelWidth: Self.labelWidth,
                    glyphWidth: Self.glyphWidth
                )
            }
        }
    }

    // MARK: - Dismiss button

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Got it")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
        .tint(GameMode.tutorial.accentColor)
    }
}

// MARK: - Mini card thumbnail

private struct MiniCardThumbnail: View {
    let card: SetCard

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SetCardLayoutView(card: card, symbolSize: 11)
            .padding(3)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(faceColor)
            .clipShape(.rect(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(hairlineColor, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.10), radius: 2, y: 1)
    }

    private var faceColor: Color {
        colorScheme == .dark
            ? Color(red: 0.165, green: 0.165, blue: 0.180)
            : Color(red: 1.000, green: 0.997, blue: 0.988)
    }

    private var hairlineColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.16)
            : Color.black.opacity(0.20)
    }
}

// MARK: - Attribute row

private struct AttributeRow: View {
    let attribute: CardAttribute
    let cards: [SetCard]
    let outcome: AttributeOutcome
    let labelWidth: CGFloat
    let glyphWidth: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: labelWidth, alignment: .leading)

            HStack(spacing: 2) {
                ForEach(cards) { card in
                    AttributeGlyph(card: card, attribute: attribute)
                        .frame(width: glyphWidth, height: glyphWidth)
                }
            }

            Spacer(minLength: 4)

            VerdictPill(outcome: outcome)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(rowBackground, in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var label: String {
        switch attribute {
        case .count: return "Number"
        default: return attribute.label.capitalized
        }
    }

    private var rowBackground: Color {
        outcome == .mixed ? Color.red.opacity(0.08) : .clear
    }

    private var accessibilityLabel: String {
        "\(label): \(describe(cards, attribute: attribute))"
    }
}

// MARK: - Attribute glyph

private struct AttributeGlyph: View {
    let card: SetCard
    let attribute: CardAttribute

    var body: some View {
        switch attribute {
        case .shape:
            Image(systemName: card.shape.systemName(for: .empty))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
        case .count:
            Text(card.count.numericDigit)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(.primary)
        case .color:
            Circle()
                .fill(card.color.color)
                .frame(width: 18, height: 18)
        case .fill:
            Image(systemName: fillGlyph(for: card.fill))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func fillGlyph(for fill: CardFill) -> String {
        switch fill {
        case .empty: return "circle"
        case .rightHalf: return "circle.righthalf.filled"
        case .filled: return "circle.fill"
        }
    }
}

// MARK: - Verdict pill

private struct VerdictPill: View {
    let outcome: AttributeOutcome

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.bold())
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: .capsule)
    }

    private var text: String {
        switch outcome {
        case .allSame: return "all same"
        case .allDifferent: return "all different"
        case .mixed: return "MIXED"
        }
    }

    private var color: Color {
        switch outcome {
        case .allSame, .allDifferent: return .green
        case .mixed: return .red
        }
    }

    private var icon: String {
        switch outcome {
        case .allSame, .allDifferent: return "checkmark"
        case .mixed: return "xmark"
        }
    }
}

// MARK: - File-local extensions

private extension CardCount {
    var numericDigit: String {
        switch self {
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        }
    }
}

// MARK: - Previews

#Preview("Valid trio") {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]
    TutorialVerdictCard(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(Color(red: 0.955, green: 0.940, blue: 0.910))
}

#Preview("Mixed fill only") {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
    ]
    TutorialVerdictCard(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(Color(red: 0.955, green: 0.940, blue: 0.910))
}

#Preview("Mixed color and shape") {
    let cards = [
        SetCard(shape: .circle, count: .two, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .filled),
        SetCard(shape: .triangle, count: .two, color: .red, fill: .filled)
    ]
    TutorialVerdictCard(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    .background(Color(red: 0.955, green: 0.940, blue: 0.910))
}
