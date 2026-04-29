//
//  ExampleTrioView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ExampleTrioView: View {
    let cards: [SetCard]
    let isSet: Bool
    let explanation: String
    var animateOnAppear: Bool = false

    @State private var hasAppeared = false

    private var shouldHide: Bool {
        animateOnAppear && !hasAppeared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    ExampleCard(card: card)
                        .opacity(shouldHide ? 0 : 1)
                        .offset(y: shouldHide ? 16 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.85)
                                .delay(Double(index) * 0.08),
                            value: hasAppeared
                        )
                }
            }

            HStack(spacing: 8) {
                Image(systemName: isSet ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isSet ? .green : .red)
                    .font(.title3)
                    .scaleEffect(shouldHide ? 0.6 : 1)
                    .opacity(shouldHide ? 0 : 1)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7).delay(0.4),
                        value: hasAppeared
                    )
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(shouldHide ? 0 : 1)
                    .animation(.easeIn(duration: 0.25).delay(0.45), value: hasAppeared)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isSet ? "Valid set" : "Not a set"): \(explanation)")
        .onAppear {
            hasAppeared = true
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ExampleTrioView(
            cards: [
                SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
                SetCard(shape: .square, count: .two, color: .green, fill: .empty),
                SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf)
            ],
            isSet: true,
            explanation: "Every attribute is different.",
            animateOnAppear: true
        )
        ExampleTrioView(
            cards: [
                SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
                SetCard(shape: .circle, count: .one, color: .red, fill: .filled),
                SetCard(shape: .circle, count: .one, color: .red, fill: .empty)
            ],
            isSet: false,
            explanation: "Two filled, one empty — fill is mixed."
        )
    }
    .padding()
}
