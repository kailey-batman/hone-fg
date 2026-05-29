
import AppKit
import SwiftUI

// MARK: - Callout Shape (rounded rect with upward arrow)

struct CalloutShape: Shape {
    var arrowX: CGFloat = 0.75 // fractional position along top edge
    var arrowWidth: CGFloat = 14
    var arrowHeight: CGFloat = 10
    var cornerRadius: CGFloat = 12

    func path(in rect: CGRect) -> Path {
        let bodyTop = arrowHeight
        let arrowMid = rect.width * arrowX
        let arrowLeft = arrowMid - arrowWidth / 2
        let arrowRight = arrowMid + arrowWidth / 2

        var path = Path()

        // Start at top-left of arrow
        path.move(to: CGPoint(x: arrowLeft, y: bodyTop))
        // Arrow tip
        path.addLine(to: CGPoint(x: arrowMid, y: 0))
        path.addLine(to: CGPoint(x: arrowRight, y: bodyTop))
        // Top-right corner
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: bodyTop))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: bodyTop + cornerRadius),
                          control: CGPoint(x: rect.width, y: bodyTop))
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.width - cornerRadius, y: rect.height),
                          control: CGPoint(x: rect.width, y: rect.height))
        // Bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height - cornerRadius),
                          control: CGPoint(x: 0, y: rect.height))
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: bodyTop + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: cornerRadius, y: bodyTop),
                          control: CGPoint(x: 0, y: bodyTop))
        path.closeSubpath()

        return path
    }
}

// MARK: - Tip View

struct MenuBarTipView: View {
    var body: some View {
        ZStack {
            CalloutShape(arrowX: 0.88)
                .fill(Color.honeBase)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

            VStack(spacing: 4) {
                Spacer().frame(height: 14) // offset for arrow
                HStack(spacing: 7) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.honeAccent)
                    Text("Find Hone up here anytime")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .frame(width: 230, height: 64)
    }
}

// MARK: - Service

class MenuBarTipService {
    static let shared = MenuBarTipService()
    private var tipWindow: NSWindow?

    func show(near statusItemButton: NSButton? = nil) {
        guard tipWindow == nil else { return }

        let windowWidth: CGFloat = 230
        let windowHeight: CGFloat = 64
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let menuBarHeight = NSStatusBar.system.thickness

        // Position just below the menu bar, toward the right where menu bar items live
        let screenWidth = screen.frame.width
        let x = screenWidth - windowWidth - 8
        let y = screen.frame.height - menuBarHeight - windowHeight - 2

        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false // shadow is in the SwiftUI view
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: MenuBarTipView())
        window.alphaValue = 0

        tipWindow = window
        window.orderFrontRegardless()

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            window.animator().alphaValue = 1
        }

        // Auto-dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            self.dismiss()
        }
    }

    private func dismiss() {
        guard let window = tipWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            self.tipWindow = nil
        })
    }
}
