//
//  SetCardLayoutView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardLayoutView: View {
    let card: SetCard
    var symbolSize: Double = 32
    var pulsesShape: Bool = false
    var pulsesColor: Bool = false
    var pulseToken: Int = 0
    let horizontalSpacing = 5.0
    let verticalSpacing = 2.0

    var body: some View {
        switch card.count {
        case .one:
            symbol
        case .two:
            HStack(spacing: horizontalSpacing) {
                symbol
                symbol
            }
        case .three:
            VStack(spacing: verticalSpacing) {
                symbol

                HStack(spacing: horizontalSpacing) {
                    symbol
                    symbol
                }
            }
        }
    }

    private var symbol: some View {
        SetSymbolView(
            card: card,
            symbolSize: symbolSize,
            pulsesShape: pulsesShape,
            pulsesColor: pulsesColor,
            pulseToken: pulseToken
        )
    }
}

#Preview {
    SetCardLayoutView(card: .example)
}
