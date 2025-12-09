//
//  SettingsView.swift
//  MiddleQuit
//
//  Created by Mat Trocha on 08/12/2025.
//

import SwiftUI

struct SettingsView: View {
    let preferences: Preferences
    let onToggleShowIcon: (Bool) -> Void

    @State private var showStatusItem: Bool
    @State private var activationMode: Preferences.ActivationMode

    init(preferences: Preferences, onToggleShowIcon: @escaping (Bool) -> Void) {
        self.preferences = preferences
        self.onToggleShowIcon = onToggleShowIcon
        // Seed state from current preferences
        _showStatusItem = State(initialValue: preferences.showStatusItem)
        _activationMode = State(initialValue: preferences.activationMode)
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { showStatusItem },
                    set: { newValue in
                        showStatusItem = newValue
                        preferences.showStatusItem = newValue
                        onToggleShowIcon(newValue)
                    }
                ))

                Picker("Activation", selection: Binding(
                    get: { activationMode },
                    set: { newValue in
                        activationMode = newValue
                        preferences.activationMode = newValue
                        // EventTapManager reads activation mode dynamically via the provider closure in AppDelegate
                    }
                )) {
                    ForEach(Preferences.ActivationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }
}

#Preview {
    let prefs = Preferences()
    return SettingsView(preferences: prefs, onToggleShowIcon: { _ in })
}
