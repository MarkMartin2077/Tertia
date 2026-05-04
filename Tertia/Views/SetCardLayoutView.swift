//
//  SetCardLayoutView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

struct SetCardLayoutView: View {
    let card: SetCard
    /// When `nil` (the default for board cards), the size is picked from
    /// the horizontal size class — 32pt on iPhone-class containers, 64pt
    /// on iPad-class containers. iPad split-view at narrow widths reports
    /// `.compact` and correctly falls back to 32pt. Pass an explicit value
    /// only for fixed-size contexts — `ExampleCard` (onboarding hints)
    /// intentionally uses a smaller fixed size.
    var symbolSize: Double? = nil
    var pulsesShape: Bool = false
    var pulsesColor: Bool = false
    var pulseToken: Int = 0
    let horizontalSpacing = 5.0
    let verticalSpacing = 2.0

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var resolvedSymbolSize: Double {
        if let symbolSize { return symbolSize }
        return horizontalSizeClass == .regular ? 64 : 32
    }

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
            symbolSize: resolvedSymbolSize,
            pulsesShape: pulsesShape,
            pulsesColor: pulsesColor,
            pulseToken: pulseToken
        )
    }
}

#Preview {
    SetCardLayoutView(card: .example)
}
