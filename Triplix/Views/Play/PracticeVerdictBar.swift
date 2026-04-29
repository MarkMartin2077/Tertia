//
//  PracticeVerdictBar.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct PracticeVerdictBar: View {
    let explanation: SetExplanation
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 14) {
                Image(systemName: explanation.isSet ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(verdictColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryText)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if !secondaryText.isEmpty {
                        Text(secondaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
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
        .accessibilityLabel(explanation.isSet ? "Valid set" : "Not a set")
        .accessibilityValue(secondaryText.isEmpty ? primaryText : "\(primaryText). \(secondaryText)")
        .accessibilityHint("Double tap to continue")
    }

    private var verdictColor: Color {
        explanation.isSet ? .green : .red
    }

    private var primaryText: String {
        if explanation.isSet { return "It's a set!" }
        let failing = explanation.failingAttributes.map(\.label)
        switch failing.count {
        case 0: return "Not a set"
        case 1: return "Not a set — \(failing[0]) is mixed"
        case 2: return "Not a set — \(failing[0]) and \(failing[1]) are mixed"
        default: return "Not a set — multiple attributes are mixed"
        }
    }

    private var secondaryText: String {
        if !explanation.isSet { return "Tap to try again" }

        let allSame = explanation.analyses
            .filter { $0.outcome == .allSame }
            .map(\.attribute.label)
        let allDifferent = explanation.analyses
            .filter { $0.outcome == .allDifferent }
            .map(\.attribute.label)

        var parts: [String] = []
        if !allSame.isEmpty {
            parts.append("Same: \(allSame.joined(separator: ", "))")
        }
        if !allDifferent.isEmpty {
            parts.append("Different: \(allDifferent.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview("Valid set") {
    PracticeVerdictBar(
        explanation: explain([
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .square, count: .two, color: .green, fill: .empty),
            SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
        ]),
        onDismiss: {}
    )
}

#Preview("Mixed fill") {
    PracticeVerdictBar(
        explanation: explain([
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
            SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
        ]),
        onDismiss: {}
    )
}
