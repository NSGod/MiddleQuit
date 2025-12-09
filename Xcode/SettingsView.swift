//
//  SettingsView.swift
//  MiddleQuit
//
//  Created by Mat Trocha on 08/12/2025.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject private var model: SettingsModel
    private let onToggleShowIcon: (Bool) -> Void

    init(preferences: Preferences, onToggleShowIcon: @escaping (Bool) -> Void) {
        self.model = SettingsModel(preferences: preferences)
        self.onToggleShowIcon = onToggleShowIcon
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show Menu Bar Icon", isOn: $model.showStatusItem)
                    .help("When off, the app runs in the background. Open Settings (⌘,) to enable it again.")
            }
        }
        .onChange(of: model.showStatusItem) { newValue in
            onToggleShowIcon(newValue)
        }
        .padding()
        .frame(width: 420)
    }
}

// A small observable wrapper so SwiftUI updates when the preference changes
final class SettingsModel: ObservableObject {
    private let preferences: Preferences

    @Published var showStatusItem: Bool {
        didSet {
            preferences.showStatusItem = showStatusItem
        }
    }

    init(preferences: Preferences) {
        self.preferences = preferences
        self.showStatusItem = preferences.showStatusItem
    }
}
