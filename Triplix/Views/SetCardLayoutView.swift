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
    let horizontalSpacing = 5.0
    let verticalSpacing = 2.0

    var body: some View {
        switch card.count {
        case .one:
            SetSymbolView(card: card, symbolSize: symbolSize)
        case .two:
            HStack(spacing: horizontalSpacing) {
                SetSymbolView(card: card, symbolSize: symbolSize)
                SetSymbolView(card: card, symbolSize: symbolSize)
            }
        case .three:
            VStack(spacing: verticalSpacing) {
                SetSymbolView(card: card, symbolSize: symbolSize)

                HStack(spacing: horizontalSpacing) {
                    SetSymbolView(card: card, symbolSize: symbolSize)
                    SetSymbolView(card: card, symbolSize: symbolSize)
                }
            }
        }
    }
}

#Preview {
    SetCardLayoutView(card: .example)
}
