//
//  SetSymbolView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetSymbolView: View {
    let card: SetCard
    let symbolSize = 32.0
    

    var body: some View {
        Image(systemName: card.shape.systemName(for: card.fill))
            .frame(width: symbolSize, height: symbolSize)
            .font(.system(size: symbolSize))
            .foregroundStyle(card.color.color)
    }
}

#Preview {
    
    SetSymbolView(card: .example)
}
