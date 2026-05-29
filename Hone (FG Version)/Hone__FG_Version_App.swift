import SwiftUI

@main
struct FGHoneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var rewriteService = RewriteService.shared

    var body: some Scene {
        MenuBarExtra("Hone", systemImage: "pencil.and.scribble") {
            MenuBarView()
                .environmentObject(appDelegate.appState)
                .environmentObject(rewriteService)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.appState)
        }
    }
}
