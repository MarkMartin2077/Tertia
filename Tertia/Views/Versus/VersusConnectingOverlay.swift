//
//  VersusConnectingOverlay.swift
//  Tertia
//
//  Shown briefly on the guest peer while it waits for the host's deck
//  seed message. Once `hasReceivedDeck` flips true, this overlay fades
//  out and the board appears.
//

import SwiftUI

struct VersusConnectingOverlay: View {
    let opponentName: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to \(opponentName)…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(opponentName)")
    }
}
