import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @Binding var hotkey: HotkeyCombo?
    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            // Display current shortcut or placeholder
            Text(isRecording ? "Press keys..." : (hotkey?.displayString ?? "None"))
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isRecording ? .accentColor : (hotkey == nil ? .secondary : .primary))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(minWidth: 90, alignment: .center)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                )

            Button(isRecording ? "Cancel" : "Record") {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if hotkey != nil && !isRecording {
                Button("Clear") {
                    hotkey = nil
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.callout)
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            self.captureShortcut(from: event)
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func captureShortcut(from event: NSEvent) {
        stopRecording()

        // Escape = cancel without saving
        guard event.keyCode != 53 else { return }

        let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !mods.isEmpty else { return }

        // Build human-readable display string
        var display = ""
        if mods.contains(.control) { display += "⌃" }
        if mods.contains(.option)  { display += "⌥" }
        if mods.contains(.shift)   { display += "⇧" }
        if mods.contains(.command) { display += "⌘" }
        display += (event.charactersIgnoringModifiers ?? "").uppercased()

        // Convert to Carbon modifier flags
        var carbonMods: UInt32 = 0
        if mods.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if mods.contains(.option)  { carbonMods |= UInt32(optionKey) }
        if mods.contains(.shift)   { carbonMods |= UInt32(shiftKey) }
        if mods.contains(.control) { carbonMods |= UInt32(controlKey) }

        hotkey = HotkeyCombo(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonMods,
            displayString: display
        )
    }
}
