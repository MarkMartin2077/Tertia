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

                Section("Help") {
                    NavigationLink("How to Play") {
                        RulesView()
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
