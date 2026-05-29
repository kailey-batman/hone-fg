import AppKit
import SwiftUI

class HUDService {
    static let shared = HUDService()

    private var window: NSWindow?
    private var dismissTask: Task<Void, Never>?

    func show(icon: String, message: String, duration: Double = 1.5) {
        dismissTask?.cancel()
        DispatchQueue.main.async {
            self.present(icon: icon, message: message, duration: duration)
        }
    }

    private func present(icon: String, message: String, duration: Double) {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 180, height: 110),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.level = .floating
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = true
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window = win
        }

        window?.contentView = NSHostingView(rootView: HUDView(icon: icon, message: message))

        // Position center-screen, slightly above middle
        if let screen = NSScreen.main {
            let sf = screen.frame
            let wf = window!.frame
            window?.setFrameOrigin(NSPoint(
                x: sf.midX - wf.width / 2,
                y: sf.midY - wf.height / 2 + 80
            ))
        }

        window?.alphaValue = 0
        window?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.window?.animator().alphaValue = 1
        }

        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self.dismiss() }
        }
    }

    private func dismiss() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            self.window?.animator().alphaValue = 0
        }, completionHandler: {
            self.window?.orderOut(nil)
        })
    }
}

struct HUDView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 160, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.black.opacity(0.72))
        )
        .padding(10)
    }
}
