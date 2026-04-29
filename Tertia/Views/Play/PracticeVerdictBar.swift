//
//  PracticeVerdictBar.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct PracticeVerdictBar: View {
    let cards: [SetCard]
    let explanation: SetExplanation
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: explanation.isSet ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(verdictColor)
                    Text(explanation.isSet ? "It's a trio!" : "Not a trio")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: 4) {
                    ForEach(CardAttribute.allCases) { attribute in
                        attributeRow(attribute)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(verdictColor.opacity(0.5), lineWidth: 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(explanation.isSet ? "Valid trio" : "Not a trio")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double tap to continue")
    }

    private var verdictColor: Color {
        explanation.isSet ? .green : .red
    }

    private func attributeRow(_ attribute: CardAttribute) -> some View {
        let outcome = explanation.outcome(for: attribute) ?? .mixed
        return HStack(spacing: 10) {
            Image(systemName: outcomeIcon(outcome))
                .font(.caption.weight(.semibold))
                .foregroundStyle(outcomeColor(outcome))
                .frame(width: 16)
            Text(attribute.label.capitalized)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .frame(width: 52, alignment: .leading)
            Text(describe(cards, attribute: attribute))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func outcomeIcon(_ outcome: AttributeOutcome) -> String {
        switch outcome {
        case .allSame: "equal.circle.fill"
        case .allDifferent: "arrow.left.and.right.circle.fill"
        case .mixed: "xmark.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: AttributeOutcome) -> Color {
        switch outcome {
        case .allSame, .allDifferent: .green
        case .mixed: .red
        }
    }

    private var accessibilityValue: String {
        let headline = explanation.isSet ? "It's a trio." : "Not a trio."
        let rows = CardAttribute.allCases.map { attr in
            "\(attr.label.capitalized): \(describe(cards, attribute: attr))"
        }.joined(separator: ". ")
        return "\(headline) \(rows)"
    }
}

#Preview("Valid trio") {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .two, color: .green, fill: .empty),
        SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
    ]
    PracticeVerdictBar(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
}

#Preview("Mixed fill") {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
    ]
    PracticeVerdictBar(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
}

#Preview("Mixed color") {
    let cards = [
        SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
        SetCard(shape: .square, count: .one, color: .green, fill: .filled),
        SetCard(shape: .triangle, count: .one, color: .red, fill: .filled)
    ]
    PracticeVerdictBar(
        cards: cards,
        explanation: explain(cards),
        onDismiss: {}
    )
}
