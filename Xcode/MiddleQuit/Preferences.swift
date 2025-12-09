//
//  Preferences.swift
//  MiddleQuit
//
//  Created by Mat Trocha on 08/12/2025.
//

import Foundation
import AppKit

final class Preferences {
    private let defaults = UserDefaults.standard
    private let showKey = "showStatusItem"
    private let activationModeKey = "activationMode"

    enum ActivationMode: String, CaseIterable, Identifiable {
        case none
        case command
        case option
        case control
        case shift

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .none: return "Middle Click"
            case .command: return "⌘ Command + Middle Click"
            case .option: return "⌥ Option + Middle Click"
            case .control: return "⌃ Control + Middle Click"
            case .shift: return "⇧ Shift + Middle Click"
            }
        }
    }

    var showStatusItem: Bool {
        get {
            // Default to true (visible)
            if defaults.object(forKey: showKey) == nil {
                return true
            }
            return defaults.bool(forKey: showKey)
        }
        set {
            defaults.set(newValue, forKey: showKey)
        }
    }

    var activationMode: ActivationMode {
        get {
            if let raw = defaults.string(forKey: activationModeKey),
               let mode = ActivationMode(rawValue: raw) {
                return mode
            }
            // Default: plain middle click
            return .none
        }
        set {
            defaults.set(newValue.rawValue, forKey: activationModeKey)
        }
    }
}

