//
//  SettingsView.swift
//  Tertia
//
//  Created by Mark Martin on 4/28/26.
//

import SwiftUI

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreference: ColorSchemePreference = .system
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @Environment(GameCenterService.self) private var gameCenter

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $colorSchemePreference) {
                        ForEach(ColorSchemePreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                }

                Section("Audio & Haptics") {
                    Toggle("Sound Effects", isOn: $soundEnabled)
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                }

                Section("Game Center") {
                    GameCenterRow(service: gameCenter)
                }

                Section("Help") {
                    NavigationLink("How to Play") {
                        RulesView()
                    }
                    Link(destination: AppLinks.support) {
                        ExternalLinkRow(title: "Support", systemImage: "questionmark.circle")
                    }
                }

                Section("Legal") {
                    Link(destination: AppLinks.termsOfService) {
                        ExternalLinkRow(title: "Terms of Service", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.privacyPolicy) {
                        ExternalLinkRow(title: "Privacy Policy", systemImage: "lock.shield")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                }
            }
            .boardBackground()
            .navigationTitle("Settings")
        }
    }
}

private struct GameCenterRow: View {
    let service: GameCenterService

    var body: some View {
        if service.isAuthenticated {
            authenticatedRow
        } else {
            unauthenticatedRow
        }
    }

    private var authenticatedRow: some View {
        Button {
            service.openDashboard()
        } label: {
            LabeledContent {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open Game Center")
                        .foregroundStyle(.primary)
                    if let name = service.localPlayerDisplayName {
                        Text("Signed in as \(name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Game Center")
    }

    @ViewBuilder
    private var unauthenticatedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not signed in")
                .font(.subheadline.weight(.semibold))
            if let message = service.lastErrorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !service.hasCompletedFirstAttempt {
                Text("Authenticating…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Game Center didn't sign you in. Open iOS Settings to verify your account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Button("Retry", action: service.authenticate)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Open iOS Settings", destination: url)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ExternalLinkRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Opens \(title) in your browser")
        .accessibilityAddTraits(.isLink)
    }
}

#Preview {
    SettingsView()
        .environment(GameCenterService())
}
