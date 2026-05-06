//
//  VersusModeSelectView.swift
//  Tertia
//
//  Sheet-presented variant picker. Three radio cards (Normal / First to 10
//  / Co-op), one sticky "Find a Match" CTA at the bottom, an Invite Friend
//  toolbar action. Tapping Find a Match dismisses the sheet and asks the
//  PlayCoordinator to launch the matchmaker with the chosen variant.
//
//  Default selection persists in @AppStorage so the user re-opens to the
//  variant they last played.
//

import SwiftUI

struct VersusModeSelectView: View {
    /// Fired when the user commits to a variant + intent. Sheet dismisses
    /// and the coordinator opens the matchmaker.
    let onStart: (VersusVariant, VersusMatchIntent) -> Void
    let onCancel: () -> Void

    @Environment(VersusStore.self) private var versusStore
    @AppStorage("lastVersusVariant") private var lastVariantRaw: String = VersusVariant.normal.rawValue
    /// Tracks the first time the user has acknowledged the new variants
    /// (by opening this sheet). After acknowledgement, the "NEW" badge
    /// drops off so the picker stops shouting at returning players.
    @AppStorage("versusVariantsAcknowledgedAt") private var acknowledgedAt: Double = 0

    private var selectedVariant: VersusVariant {
        VersusVariant(rawValue: lastVariantRaw) ?? .normal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    cardsSection
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 140) // leave room for the sticky CTA
            }
            .navigationTitle("Choose a Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Invite Friend is gated to Normal because GameKit
                    // invites don't carry the inviter's variant — the
                    // accepting peer would always default to .normal and
                    // mismatch-decline anything else. Gating up front
                    // keeps that failure mode out of the user's path.
                    if selectedVariant == .normal {
                        Button {
                            onStart(selectedVariant, .inviteFriend)
                        } label: {
                            Label("Invite", systemImage: "person.crop.circle.badge.plus")
                        }
                        .accessibilityLabel("Invite friend to \(selectedVariant.shortName)")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
            .onAppear {
                if acknowledgedAt == 0 {
                    acknowledgedAt = Date.now.timeIntervalSince1970
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(spacing: 10) {
            ForEach(VersusVariant.allCases, id: \.self) { variant in
                VersusVariantCard(
                    variant: variant,
                    title: copy(for: variant).title,
                    tagline: copy(for: variant).tagline,
                    description: copy(for: variant).description,
                    glyph: copy(for: variant).glyph,
                    accent: accent(for: variant),
                    isSelected: variant == selectedVariant,
                    statBlurb: statBlurb(for: variant),
                    showsNewBadge: showsNewBadge(for: variant),
                    onTap: {
                        select(variant)
                    }
                )
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button {
                onStart(selectedVariant, .quickMatch)
            } label: {
                HStack {
                    Text("Find a Match")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title3)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(accent(for: selectedVariant))

            Text("Looking for someone in \(selectedVariant.shortName)…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .padding(.top, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Selection

    private func select(_ variant: VersusVariant) {
        guard variant != selectedVariant else { return }
        lastVariantRaw = variant.rawValue
    }

    // MARK: - Per-variant copy

    private struct CardCopy {
        let title: String
        let tagline: String
        let description: String
        let glyph: String
    }

    private func copy(for variant: VersusVariant) -> CardCopy {
        switch variant {
        case .normal:
            return CardCopy(
                title: "NORMAL",
                tagline: "Race for the highest score, no clock",
                description: "Race for the highest score. No clock. Ends when the deck runs out.",
                glyph: "infinity"
            )
        case .firstTo10:
            return CardCopy(
                title: "FIRST TO 10",
                tagline: "Sprint to 10 trios",
                description: "First player to claim 10 trios wins. Fast-paced races.",
                glyph: "10.circle.fill"
            )
        case .coop:
            return CardCopy(
                title: "CO-OP",
                tagline: "Work through the deck together",
                description: "Team up. Work through the deck together — no winner, just speed and accuracy.",
                glyph: "person.2.fill"
            )
        }
    }

    private func accent(for variant: VersusVariant) -> Color {
        variant.accent
    }

    // MARK: - Stats blurb

    /// Per-variant short stat pulled from `VersusStore`. Returns nil when
    /// the player has no history for this variant so the card renders
    /// without an empty "0–0" suffix.
    private func statBlurb(for variant: VersusVariant) -> String? {
        switch variant {
        case .normal, .firstTo10:
            let wins = versusStore.winCount(in: variant)
            let losses = versusStore.lossCount(in: variant)
            guard wins + losses > 0 else { return nil }
            return "\(wins)–\(losses) W-L"
        case .coop:
            let completed = versusStore.coopCompletedCount
            guard completed > 0 else { return nil }
            return "\(completed) run\(completed == 1 ? "" : "s")"
        }
    }

    // MARK: - "NEW" badge

    /// Returns true for non-Normal variants until 30 days after the user
    /// first opened this sheet.
    private func showsNewBadge(for variant: VersusVariant) -> Bool {
        guard variant != .normal else { return false }
        guard acknowledgedAt > 0 else { return true }
        let acknowledgedDate = Date(timeIntervalSince1970: acknowledgedAt)
        let thirtyDays: TimeInterval = 30 * 24 * 60 * 60
        return Date.now.timeIntervalSince(acknowledgedDate) < thirtyDays
    }
}

#Preview {
    VersusModeSelectView(
        onStart: { variant, intent in
            print("Start: \(variant.rawValue) / \(intent.rawValue)")
        },
        onCancel: { print("Cancel") }
    )
    .environment(VersusStore())
}
