//
//  SetCardView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardView: View {
    let card: SetCard
    let isSelected: Bool
    let isInvalid: Bool
    var pulsingAttributes: Set<CardAttribute> = []
    var pulseToken: Int = 0
    let action: () -> Void

    private var pulsesShape: Bool {
        !pulsingAttributes.isDisjoint(with: [.shape, .count, .fill])
    }

    private var pulsesColor: Bool {
        pulsingAttributes.contains(.color)
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
                .background(.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: shadowColor, radius: shadowRadius)
        }
        .id(card.id)
    }

    private var borderColor: Color {
        if isInvalid { return .red }
        if isSelected { return .yellow }
        return .secondary
    }

    private var borderWidth: CGFloat {
        (isSelected || isInvalid) ? 3 : 1
    }

    private var shadowColor: Color {
        if isInvalid { return .red }
        if isSelected { return .yellow }
        return .clear
    }

    private var shadowRadius: CGFloat {
        (isSelected || isInvalid) ? 8 : 0
    }
}

#Preview {
    SetCardView(card: .example, isSelected: false, isInvalid: false) { }
}
