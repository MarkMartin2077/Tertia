//
//  SetCardView.swift
//  Triplix
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardView: View {
    let card: SetCard
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            SetCardLayoutView(card: card)
                .padding(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isSelected ? .yellow : .secondary, lineWidth: isSelected ? 3 : 1)
                }
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: isSelected ? .yellow : .clear, radius: isSelected ? 8 : 0)
        }
        .id(card.id)
    }
}

#Preview {
    SetCardView(card: .example, isSelected: false) { }
}
