//
//  MiddleQuitApp.swift
//  MiddleQuit
//
//  Created by Mat Trocha on 08/12/2025.
//

import SwiftUI
import AppKit

@main
struct MiddleQuitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Provide a real Settings window with a toggle for the menu bar icon
        Settings {
            SettingsView(
                preferences: appDelegate.preferences,
                onToggleShowIcon: { show in
                    appDelegate.applyStatusItemVisibility(show: show)
                }
            )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Make preferences internal so SettingsView can access it via appDelegate
    let preferences = Preferences()
    private let eventTapManager = EventTapManager()
    private let dockHelper = DockAccessibilityHelper()
    private let quitController = QuitController()
    private let launchAtLogin = LaunchAtLoginManager()
    private var statusController: StatusItemController!

    // Polling timer to detect when AX trust flips to true after prompting
    private var axPollingTimer: Timer?
    // Guard to avoid starting the tap twice
    private var hasStartedEventTap = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(
            preferences: preferences,
            onToggleShowIcon: { [weak self] show in
                self?.applyStatusItemVisibility(show: show)
            },
            onOpenAccessibility: { [weak self] in
                self?.promptForAccessibilityAndAutoStart()
            },
            onToggleLaunchAtLogin: { [weak self] in
                guard let self else { return }
                let result = self.launchAtLogin.toggle()
                switch result {
                case .requiresApproval:
                    self.launchAtLogin.openLoginItemsSettingsIfAvailable()
                case .failed(let error):
                    let alert = NSAlert()
                    alert.messageText = "Couldn’t Update Login Item"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                case .unavailable:
                    let alert = NSAlert()
                    alert.messageText = "Not Supported on This macOS Version"
                    alert.informativeText = "Enabling launch at login without a helper app requires macOS 13 or later."
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                default:
                    break
                }
            },
            isLaunchAtLoginEnabled: { [weak self] in
                return self?.launchAtLogin.isEnabled ?? false
            },
            getActivationMode: { [weak self] in
                self?.preferences.activationMode ?? .none
            },
            onSetActivationMode: { [weak self] mode in
                guard let self else { return }
                self.preferences.activationMode = mode
                // EventTapManager reads mode dynamically
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        applyStatusItemVisibility(show: preferences.showStatusItem)
        ensureAccessibilityAndStart()
    }

    // MARK: - Accessibility flow (Option C)

    // Show the system-managed AX prompt and auto-start when trust becomes true.
    private func promptForAccessibilityAndAutoStart() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission"
        alert.informativeText = "MiddleQuit needs Accessibility permission to handle mouse clicks. macOS will show a prompt. After allowing, MiddleQuit will become active automatically."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        DockAccessibilityHelper.requestAXPermissionIfNeeded()
        beginAXTrustPolling(timeout: 30.0, interval: 0.5)
    }

    private func beginAXTrustPolling(timeout: TimeInterval, interval: TimeInterval) {
        axPollingTimer?.invalidate()

        if DockAccessibilityHelper.isAXEnabled() {
            ensureAccessibilityAndStart()
            return
        }

        let deadline = Date().addingTimeInterval(timeout)

        axPollingTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else { return }
            if DockAccessibilityHelper.isAXEnabled() {
                timer.invalidate()
                self.axPollingTimer = nil
                self.ensureAccessibilityAndStart()
            } else if Date() >= deadline {
                timer.invalidate()
                self.axPollingTimer = nil
                self.offerAccessibilitySettingsFallback()
            }
        }

        RunLoop.main.add(axPollingTimer!, forMode: .common)
    }

    private func offerAccessibilitySettingsFallback() {
        let fallback = NSAlert()
        fallback.messageText = "Accessibility Not Enabled"
        fallback.informativeText = "You can enable Accessibility for MiddleQuit in System Settings. Would you like to open it now?"
        fallback.alertStyle = .warning
        fallback.addButton(withTitle: "Open Settings")
        fallback.addButton(withTitle: "Cancel")
        let result = fallback.runModal()
        guard result == .alertFirstButtonReturn else { return }

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Event tap lifecycle

    private func ensureAccessibilityAndStart() {
        guard DockAccessibilityHelper.isAXEnabled() else {
            return
        }
        guard !hasStartedEventTap else {
            return
        }
        hasStartedEventTap = true

        // Rebuild menu so the "Open Accessibility Settings" item disappears
        statusController.rebuildMenu()

        eventTapManager.start(activationMode: { [weak self] in
            self?.preferences.activationMode ?? .none
        }) { [weak self] point in
            guard let self else { return false }
            if let pid = self.dockHelper.pidForDockTile(at: point) {
                self.quitController.gracefulQuit(pid: pid)
                return self.eventTapManager.canSwallow
            }
            return false
        }
    }

    func applyStatusItemVisibility(show: Bool) {
        if show {
            statusController.show()
            NSApp.setActivationPolicy(.accessory) // menu bar only
        } else {
            statusController.hide()
            NSApp.setActivationPolicy(.prohibited) // fully background
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        axPollingTimer?.invalidate()
        eventTapManager.stop()
    }
}
