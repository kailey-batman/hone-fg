import AppKit
import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif

    /// AppState lives here so it exists at launch, before the MenuBarExtra is clicked
    let appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        #if canImport(Sparkle)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif

        setupHotkeys()

        // Show onboarding immediately on first launch — no click required
        if !appState.hasCompletedOnboarding {
            DispatchQueue.main.async {
                self.showOnboarding()
            }
        }
    }

    func setupHotkeys() {
        HotkeyService.shared.registerAll(profiles: appState.profiles)
        HotkeyService.shared.onHotkeyTriggered = { [weak self] profileID in
            guard let self,
                  let profile = self.appState.profiles.first(where: { $0.id == profileID })
            else { return }
            Task { @MainActor in
                RewriteService.shared.rewrite(profile: profile)
            }
        }
    }

    func showOnboarding() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Hone"
        window.center()
        window.isReleasedWhenClosed = false
        onboardingWindow = window

        let view = OnboardingView(onDismiss: { [weak self, weak window] in
            window?.close()
            self?.onboardingWindow = nil
        }).environmentObject(appState)

        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
