//
//  ExampleCard.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct ExampleCard: View {
    let card: SetCard
    var symbolSize: Double = 18

    var body: some View {
        SetCardLayoutView(card: card, symbolSize: symbolSize)
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.secondary, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: 12))
            .aspectRatio(1.0, contentMode: .fit)
    }
}

#Preview {
    HStack(spacing: 8) {
        ExampleCard(card: .example)
        ExampleCard(card: SetCard(shape: .square, count: .two, color: .green, fill: .empty))
        ExampleCard(card: SetCard(shape: .triangle, count: .three, color: .blue, fill: .rightHalf))
    }
    .padding()
}
