//
//  InGameAudioSheet.swift
//  Tertia
//
//  Compact in-game popover for muting music / sound effects / haptics
//  without leaving the board to dig through Settings. Bound to the same
//  `@AppStorage` keys as the Settings screen — flipping a toggle here
//  mirrors instantly to Settings and vice-versa.
//

import SwiftUI

struct InGameAudioSheet: View {
    let onDone: () -> Void

    @AppStorage("musicEnabled") private var musicEnabled: Bool = true
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @Environment(MusicService.self) private var music

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                AudioToggleRow(
                    title: "Music",
                    icon: "music.note",
                    tint: .pink,
                    isOn: $musicEnabled
                )
                .onChange(of: musicEnabled) { _, newValue in
                    music.setEnabled(newValue)
                }

                AudioToggleRow(
                    title: "Sound Effects",
                    icon: "speaker.wave.2.fill",
                    tint: .blue,
                    isOn: $soundEnabled
                )

                AudioToggleRow(
                    title: "Haptics",
                    icon: "iphone.radiowaves.left.and.right",
                    tint: .purple,
                    isOn: $hapticsEnabled
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .navigationTitle("Sound & Haptics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
        // Single short detent — the sheet is three toggles, no need to
        // take the whole screen. `.fraction` keeps it compact across
        // device sizes; `.large` is allowed as a fallback for accessibility
        // (large dynamic type might push content past the small detent).
        .presentationDetents([.fraction(0.32), .large])
        .presentationDragIndicator(.visible)
    }
}

private struct AudioToggleRow: View {
    let title: String
    let icon: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 28)
                Text(title)
                    .font(.body.weight(.medium))
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.08), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }
}

#Preview {
    Color.gray
        .sheet(isPresented: .constant(true)) {
            InGameAudioSheet(onDone: {})
                .environment(MusicService())
        }
}
