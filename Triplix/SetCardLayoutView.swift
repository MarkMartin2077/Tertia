//
//  SetCardLayoutView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardLayoutView: View {
    let card: SetCard
    let horizontalSpacing = 5.0
    let verticalSpacing = 2.0

    var body: some View {
        switch card.count {
        case .one:
            SetSymbolView(card: card)
        case .two:
            HStack(spacing: horizontalSpacing) {
                SetSymbolView(card: card)
                SetSymbolView(card: card)
            }
        case .three:
            VStack(spacing: verticalSpacing) {
                SetSymbolView(card: card)

                HStack(spacing: horizontalSpacing) {
                    SetSymbolView(card: card)
                    SetSymbolView(card: card)
                }
            }
        }
    }
}

#Preview {
    SetCardLayoutView(card: .example)
}
