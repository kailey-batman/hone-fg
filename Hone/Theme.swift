import SwiftUI
import AppKit

// MARK: — Hone Design System
// Palette: Sage & Forest — organic, premium, writing-forward

extension Color {
    /// Sage green — primary accent, brand color, buttons
    static let honeAccent    = Color(hex: "#87A987")
    /// Deep forest — menu bar & dark surfaces (intentionally always dark)
    static let honeBase      = Color(hex: "#1E2E22")
    /// Slightly lighter forest — card / row surfaces in dark panels
    static let honeSurface   = Color(hex: "#263420")
    /// Soft highlight — selected states
    static let honeHighlight = Color(hex: "#D2E7D6")
    /// Action green — buttons, interactive elements
    static let honeAction    = Color(hex: "#3B6043")
    /// Muted — secondary text on dark backgrounds
    static let honeMuted     = Color(hex: "#7A9A80")

    // MARK: Adaptive — flip between light and dark mode

    /// Main background for Settings / Onboarding panels
    static let honeLinen = Color.adaptive(
        light: "#F9F9F6",
        dark:  "#1A2420"
    )

    /// Primary text on linen surfaces
    static let honeText = Color.adaptive(
        light: "#1E2E22",
        dark:  "#E0EBE0"
    )

    /// Secondary / subdued text on linen surfaces
    static let honeSubtext = Color.adaptive(
        light: "#1E2E22",
        dark:  "#8FA88F"
    )

    /// Card / row background inside linen panels
    static let honeCard = Color.adaptive(
        light: "#FFFFFF",
        dark:  "#223028"
    )

    // MARK: Helpers

    private static func adaptive(light: String, dark: String) -> Color {
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua: return NSColor(hex: dark)
            default:        return NSColor(hex: light)
            }
        }))
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8)  & 0xFF) / 255
        let b = CGFloat(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: — Reusable Modifiers

struct HoneButtonStyle: ButtonStyle {
    var filled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(filled
                          ? Color.honeAccent.opacity(configuration.isPressed ? 0.7 : 1)
                          : Color.honeSurface.opacity(configuration.isPressed ? 0.5 : 1))
            )
            .foregroundColor(filled ? Color.honeBase : .white)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ProfileCardStyle: ViewModifier {
    var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? Color.honeSurface : Color.clear)
            )
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
