import AppKit
import Combine

@MainActor
class RewriteService: ObservableObject {
    static let shared = RewriteService()

    @Published var isProcessing = false
    @Published var statusMessage = ""

    private var statusClearTask: Task<Void, Never>?

    func rewrite(profile: Profile, apiKey: String = "") {
        guard !isProcessing else { return }

        // FG Version: prompt for email if not set
        if Config.builtInAPIKey != nil {
            let email = UserDefaults.standard.string(forKey: "hone.userEmail") ?? ""
            if email.isEmpty {
                promptForEmail()
                return
            }
        }

        // Request accessibility if not already granted — uses system prompt
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            setStatus("Grant Accessibility access, then try again", autoClear: true)
            return
        }

        isProcessing = true
        HUDService.shared.show(icon: "doc.on.doc", message: "Copying...", duration: 60)

        // Simulate Cmd+C so the selected text lands on the clipboard
        simulateCopy()

        // Give the clipboard a moment to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            let selected = NSPasteboard.general.string(forType: .string) ?? ""

            guard !selected.isEmpty else {
                self.isProcessing = false
                HUDService.shared.show(icon: "exclamationmark.circle", message: "No text selected")
                self.setStatus("No text selected", autoClear: true)
                return
            }

            HUDService.shared.show(icon: "sparkles", message: "Rewriting...", duration: 60)

            Task {
                do {
                    let providerKey = KeychainService.shared.load(for: profile.provider) ?? ""
                    let result = try await AIService.shared.rewrite(
                        text: selected,
                        systemPrompt: profile.prompt,
                        provider: profile.provider,
                        apiKey: providerKey
                    )
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result, forType: .string)
                    self.isProcessing = false

                    // Track usage — content is never sent, only metadata
                    // Prefer the logged-in Supabase email; fall back to the onboarding email field
                    let email = SupabaseService.shared.currentUser?.email
                             ?? UserDefaults.standard.string(forKey: "hone.userEmail")
                             ?? ""
                    let inputWords = selected.split(separator: " ").count
                    let outputWords = result.split(separator: " ").count
                    AnalyticsService.shared.track(
                        email: email,
                        profile: profile.name,
                        prompt: profile.prompt,
                        inputWords: inputWords,
                        outputWords: outputWords
                    )
                    let shouldAutoPaste = UserDefaults.standard.bool(forKey: "hone.autoPaste")
                    if shouldAutoPaste {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.simulatePaste()
                        }
                        HUDService.shared.show(icon: "checkmark.circle", message: "Pasted!")
                        self.setStatus("Pasted!", autoClear: true)
                    } else {
                        HUDService.shared.show(icon: "checkmark.circle", message: "Ready to paste")
                        self.setStatus("Done — paste to use", autoClear: true)
                    }
                } catch {
                    self.isProcessing = false
                    let message = self.friendlyError(error)
                    HUDService.shared.show(icon: "xmark.circle", message: message)
                    self.setStatus(message, autoClear: true)
                }
            }
        }
    }

    private func promptForEmail() {
        let alert = NSAlert()
        alert.messageText = "What's your Fieldguide email?"
        alert.informativeText = "Used to verify you're part of the team."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "you@fieldguide.io"
        input.bezelStyle = .roundedBezel
        alert.accessoryView = input

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let entered = input.stringValue.trimmingCharacters(in: .whitespaces)
            if entered.contains("@") {
                UserDefaults.standard.set(entered, forKey: "hone.userEmail")
                // Retry the rewrite — the caller can re-invoke after email is saved
                HUDService.shared.show(icon: "checkmark.circle", message: "Email saved — try again")
                setStatus("Email saved — try again", autoClear: true)
            } else {
                setStatus("Invalid email", autoClear: true)
            }
        }
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func simulateCopy() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("hostname") || msg.contains("network") || msg.contains("offline") || msg.contains("internet") {
            return "No internet connection"
        }
        if msg.contains("api key") || msg.contains("401") || msg.contains("403") {
            return "Invalid API key — check Settings"
        }
        if msg.contains("429") {
            return "Rate limit hit — try again shortly"
        }
        if msg.contains("500") || msg.contains("502") || msg.contains("503") {
            return "AI service is down — try again"
        }
        // For RewriteError types which already have good messages
        if let rewriteError = error as? RewriteError {
            return rewriteError.errorDescription ?? "Something went wrong"
        }
        return "Something went wrong"
    }

    private func setStatus(_ message: String, autoClear: Bool = false) {
        statusClearTask?.cancel()
        statusMessage = message
        if autoClear {
            statusClearTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if !Task.isCancelled {
                    self.statusMessage = ""
                }
            }
        }
    }
}
