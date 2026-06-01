import SwiftUI
import ApplicationServices

// MARK: - Data Models

struct SuggestedShortcut: Identifiable {
    let id = UUID()
    let display: String
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let all: [SuggestedShortcut] = [
        SuggestedShortcut(display: "⌘⇧R", keyCode: 15, carbonModifiers: 768),
        SuggestedShortcut(display: "⌥⇧R", keyCode: 15, carbonModifiers: 2560),
        SuggestedShortcut(display: "⌘⇧E", keyCode: 14, carbonModifiers: 768),
        SuggestedShortcut(display: "⌥⇧E", keyCode: 14, carbonModifiers: 2560),
    ]
}

// MARK: - Onboarding View

struct OnboardingView: View {
    var onDismiss: () -> Void = {}

    @EnvironmentObject var appState: AppState

    @State private var step = 0
    @State private var apiKey = ""
    @State private var email = UserDefaults.standard.string(forKey: "hone.userEmail") ?? ""
    @State private var selectedTemplate: ProfileTemplate? = nil
    @State private var profileName = ""
    @State private var profilePrompt = ""
    @State private var hotkey: HotkeyCombo? = nil
    @State private var showCheck = false
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var accessibilityTimer: Timer? = nil

    var body: some View {
        Group {
            if step == 6 {
                successScreen
            } else {
                HStack(spacing: 0) {
                    leftPanel
                    Divider()
                    rightContent
                        .id(step) // forces view replacement for transition
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(width: 660, height: 500)
        .animation(.easeInOut(duration: 0.22), value: step)
        .onDisappear {
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
        }
    }

    // MARK: Left Panel

    var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.honeAccent)
                Text("Hone")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 32)
            .padding(.bottom, 44)

            if step == 0 {
                Text("Your words,\nsharpened.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(5)
            } else if Config.builtInAPIKey != nil {
                VStack(alignment: .leading, spacing: 2) {
                    leftStepRow(index: 1, label: "Your email")
                    leftStepRow(index: 2, label: "Account")
                    leftStepRow(index: 3, label: "Your style")
                    leftStepRow(index: 4, label: "Your shortcut")
                    leftStepRow(index: 5, label: "Permissions")
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    leftStepRow(index: 1, label: "Connect Claude")
                    leftStepRow(index: 2, label: "Account")
                    leftStepRow(index: 3, label: "Your style")
                    leftStepRow(index: 4, label: "Your shortcut")
                    leftStepRow(index: 5, label: "Permissions")
                }
            }

            Spacer()

            Text("Takes about 2 minutes.")
                .font(.system(size: 11))
                .foregroundColor(Color.honeMuted)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(Color.honeBase)
    }

    func leftStepRow(index: Int, label: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(stepCircleFill(index))
                    .frame(width: 24, height: 24)
                if step > index {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(index)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(step == index ? Color.honeBase : Color.honeMuted)
                }
            }
            Text(label)
                .font(.system(size: 13, weight: step == index ? .semibold : .regular))
                .foregroundColor(
                    step == index ? .white :
                    step > index ? Color.honeAccent.opacity(0.6) :
                    Color.honeMuted
                )
        }
        .padding(.vertical, 6)
    }

    func stepCircleFill(_ index: Int) -> Color {
        if step > index { return Color.honeAction }
        if step == index { return Color.honeAccent }
        return Color.honeSurface
    }

    // MARK: Right Content Router

    @ViewBuilder
    var rightContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: Config.builtInAPIKey != nil ? AnyView(emailStep) : AnyView(apiKeyStep)
        case 2: accountStep
        case 3: templateStep
        case 4: shortcutStep
        case 5: accessibilityStep
        default: EmptyView()
        }
    }

    // MARK: Step 0 — Welcome

    var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {

                // Flow diagram
                HStack(spacing: 10) {
                    flowPill(icon: "text.cursor", label: "Select")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.honeAccent.opacity(0.4))
                    flowPill(icon: "keyboard", label: "Shortcut")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.honeAccent.opacity(0.4))
                    flowPill(icon: "sparkles", label: "Rewritten")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Welcome to Hone")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(Color.honeText)

                    Text("Select text anywhere on your Mac, press a keyboard shortcut, and get it rewritten instantly — in your voice, for your audience.")
                        .font(.system(size: 14))
                        .foregroundColor(Color.honeSubtext.opacity(0.6))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Get Started") {
                    if Config.builtInAPIKey != nil {
                        // Skip email step if email already saved (reinstaller)
                        let hasEmail = !email.trimmingCharacters(in: .whitespaces).isEmpty
                        withAnimation { step = hasEmail ? 2 : 1 }
                    } else {
                        withAnimation { step = 1 }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.honeAction)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    func flowPill(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.honeAccent.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color.honeAction)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color.honeMuted)
        }
    }

    // MARK: Step 1 — Email (FG Version)

    var emailStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("What's your email?", sub: "Used to verify you're part of the Fieldguide team.")

            Spacer().frame(height: 28)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Work email")
                TextField("you@fieldguide.io", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .font(.system(size: 13))
            }

            Spacer()

            navRow(
                back: { withAnimation { step = 0 } },
                next: {
                    let trimmed = email.trimmingCharacters(in: .whitespaces)
                    UserDefaults.standard.set(trimmed, forKey: "hone.userEmail")
                    withAnimation { step = 2 }
                },
                nextLabel: "Continue",
                nextEnabled: email.trimmingCharacters(in: .whitespaces).contains("@")
            )
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    // MARK: Step 2 — Account (login / sign up)

    var accountStep: some View {
        OnboardingAccountStep(
            onBack: { withAnimation { step = 1 } },
            onContinue: { withAnimation { step = 3 } }
        )
    }

    // MARK: Step 1 — API Key

    var apiKeyStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heading("Connect Claude", sub: "Hone uses Claude to rewrite your text. You'll need a free Anthropic API key.")

                Spacer().frame(height: 24)

                // Numbered mini-guide
                VStack(alignment: .leading, spacing: 0) {
                    guideStep(n: 1, isLast: false) {
                        HStack(spacing: 4) {
                            Text("Go to")
                                .foregroundColor(Color.honeText.opacity(0.7))
                            Link("console.anthropic.com →", destination: URL(string: "https://console.anthropic.com")!)
                                .foregroundColor(Color.honeAccent)
                        }
                        .font(.system(size: 13))
                    }
                    guideStep(n: 2, isLast: false) {
                        Text("Sign in or create a free account")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeText.opacity(0.7))
                    }
                    guideStep(n: 3, isLast: false) {
                        Text("Click **API Keys** in the left sidebar")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeText.opacity(0.7))
                    }
                    guideStep(n: 4, isLast: false) {
                        Text("Click **Create Key** → name it anything → **Copy**")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeText.opacity(0.7))
                    }
                    guideStep(n: 5, isLast: true) {
                        Text("Paste it below ↓")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeText.opacity(0.7))
                    }
                }

                Spacer().frame(height: 16)

                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                    Text("Stored in your Mac's Keychain — never shared or logged.")
                        .font(.system(size: 11))
                }
                .foregroundColor(Color.honeAction.opacity(0.6))
                .padding(.top, 6)

                Spacer().frame(height: 32)

                navRow(
                    back: { withAnimation { step = 0 } },
                    next: {
                        appState.apiKey = apiKey.trimmingCharacters(in: .whitespaces)
                        withAnimation { step = 2 }
                    },
                    nextLabel: "Continue",
                    nextEnabled: apiKey.trimmingCharacters(in: .whitespaces).count > 20
                )
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    func guideStep<Content: View>(n: Int, isLast: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.honeAccent.opacity(0.18))
                        .frame(width: 22, height: 22)
                    Text("\(n)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.honeAction)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.honeAccent.opacity(0.2))
                        .frame(width: 1.5)
                        .frame(height: 20)
                }
            }
            VStack(alignment: .leading) {
                content()
                    .padding(.top, 2)
                if !isLast { Spacer().frame(height: 12) }
            }
            Spacer()
        }
    }

    // MARK: Step 2 — Template

    var templateStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heading("Choose your style", sub: "Pick a template to start. You can customize or add more profiles later.")

                Spacer().frame(height: 20)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(ProfileTemplate.all) { template in
                        templateCard(template, isWorkspace: false)
                    }
                }

                // Custom prompt field
                if selectedTemplate == .custom {
                    VStack(alignment: .leading, spacing: 6) {
                        fieldLabel("Your instructions")
                        ZStack(alignment: .topLeading) {
                            if profilePrompt.isEmpty {
                                Text("e.g. Rewrite in a casual, direct style. Lead with the main point. Cut filler phrases.")
                                    .foregroundColor(Color.honeSubtext.opacity(0.3))
                                    .font(.callout)
                                    .padding(8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $profilePrompt)
                                .font(.callout)
                                .frame(height: 80)
                                .scrollContentBackground(.hidden)
                        }
                        .padding(4)
                        .background(Color.honeCard.opacity(0.7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.honeAccent.opacity(0.4)))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                    .padding(.top, 14)
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Profile name")
                    TextField("e.g. Casual Slack", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 14)

                Spacer().frame(height: 24)

                navRow(
                    back: { withAnimation { step = 2 } },
                    next: { withAnimation { step = 4 } },
                    nextLabel: "Continue",
                    nextEnabled: selectedTemplate != nil &&
                        !profileName.isEmpty &&
                        (selectedTemplate != .custom || !profilePrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                )
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    func templateCard(_ template: ProfileTemplate, isWorkspace: Bool) -> some View {
        let isSelected = selectedTemplate == template
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedTemplate = template
                if profileName.isEmpty || ProfileTemplate.all.map(\.name).contains(profileName) {
                    profileName = template.name == "Custom" ? "" : template.name
                }
                if template != .custom { profilePrompt = template.prompt }
                else { profilePrompt = "" }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Color.honeAction : Color.honeAccent.opacity(0.13))
                            .frame(width: 30, height: 30)
                        Image(systemName: template.icon)
                            .font(.system(size: 13))
                            .foregroundColor(isSelected ? .white : Color.honeAction)
                    }
                    Spacer()
                    if isWorkspace && !isSelected {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.honeAction.opacity(0.4))
                    }
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(Color.honeAction)
                    }
                }
                Text(template.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.honeText)
                Text(template.tagline)
                    .font(.system(size: 11))
                    .foregroundColor(Color.honeSubtext.opacity(0.5))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.honeHighlight : (isWorkspace ? Color.honeHighlight.opacity(0.4) : Color.honeCard.opacity(0.55)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.honeAction : (isWorkspace ? Color.honeAction.opacity(0.2) : Color.clear), lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Step 3 — Shortcut

    var shortcutStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Set your trigger", sub: "Press any key combo to activate Hone. You'll use this every time you want to rewrite something.")

            Spacer().frame(height: 28)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Record a shortcut")
                ShortcutRecorderView(hotkey: $hotkey)
            }

            Spacer().frame(height: 24)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Or pick a suggestion")
                HStack(spacing: 8) {
                    ForEach(SuggestedShortcut.all) { s in
                        Button {
                            hotkey = HotkeyCombo(keyCode: s.keyCode, carbonModifiers: s.carbonModifiers, displayString: s.display)
                        } label: {
                            Text(s.display)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(hotkey?.displayString == s.display ? .white : Color.honeAction)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(hotkey?.displayString == s.display ? Color.honeAction : Color.honeAccent.opacity(0.13))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer().frame(height: 20)

            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                Text("Avoid ⌘W, ⌘C, ⌘V and ⌘Z — these conflict with common system shortcuts.")
                    .font(.system(size: 11))
            }
            .foregroundColor(Color.honeSubtext.opacity(0.35))

            Spacer()

            navRow(
                back: { withAnimation { step = 3 } },
                next: { finish() },
                nextLabel: "Finish",
                nextEnabled: hotkey != nil
            )
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    // MARK: Step 4 — Accessibility

    var accessibilityStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            heading("Allow Accessibility access",
                    sub: "Hone needs one permission to grab your selected text when you press your shortcut.")

            Spacer().frame(height: 24)

            if accessibilityGranted {
                // Granted state
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.honeAction)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Permission granted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.honeBase)
                        Text("Hone can now read your selected text.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.honeBase.opacity(0.5))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.honeAction.opacity(0.08)))
            } else {
                // Step-by-step instructions
                VStack(alignment: .leading, spacing: 0) {
                    guideStep(n: 1, isLast: false) {
                        Button {
                            let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
                            AXIsProcessTrustedWithOptions(opts)
                            startAccessibilityPolling()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Grant Access")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.honeAction))
                        }
                        .buttonStyle(.plain)
                    }
                    guideStep(n: 2, isLast: false) {
                        Text("A system dialog will appear — click **Open System Settings**")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeBase.opacity(0.7))
                    }
                    guideStep(n: 3, isLast: false) {
                        Text("Find **Hone** in the list and toggle it **on**")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeBase.opacity(0.7))
                    }
                    guideStep(n: 4, isLast: true) {
                        Text("Come back here — Hone will detect the change automatically")
                            .font(.system(size: 13))
                            .foregroundColor(Color.honeBase.opacity(0.7))
                    }
                }
            }

            Spacer()

            navRow(
                back: { withAnimation { step = 4 } },
                next: { withAnimation { step = 6 } },
                nextLabel: accessibilityGranted ? "Continue" : "Skip for now",
                nextEnabled: true
            )
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
        .onAppear {
            accessibilityGranted = AXIsProcessTrusted()
            if !accessibilityGranted { startAccessibilityPolling() }
        }
        .onDisappear {
            accessibilityTimer?.invalidate()
            accessibilityTimer = nil
        }
    }

    // MARK: Step 5 — Success

    var successScreen: some View {
        HStack(spacing: 0) {
            // Left panel (all checked)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.scribble")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.honeAccent)
                    Text("Hone")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 32)
                .padding(.bottom, 44)

                if Config.builtInAPIKey != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        leftStepRow(index: 1, label: "Your email")
                        leftStepRow(index: 2, label: "Account")
                        leftStepRow(index: 3, label: "Your style")
                        leftStepRow(index: 4, label: "Your shortcut")
                        leftStepRow(index: 5, label: "Permissions")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        leftStepRow(index: 1, label: "Connect Claude")
                        leftStepRow(index: 2, label: "Account")
                        leftStepRow(index: 3, label: "Your style")
                        leftStepRow(index: 4, label: "Your shortcut")
                        leftStepRow(index: 5, label: "Permissions")
                    }
                }

                Spacer()

                Text("You're all set!")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.honeAccent)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
            .frame(width: 200)
            .frame(maxHeight: .infinity)
            .background(Color.honeBase)

            Divider()

            // Right — success content
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    // Animated checkmark
                    ZStack {
                        Circle()
                            .fill(Color.honeAccent.opacity(0.13))
                            .frame(width: 64, height: 64)
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.honeAction)
                            .scaleEffect(showCheck ? 1 : 0.2)
                            .opacity(showCheck ? 1 : 0)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.15)) {
                            showCheck = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hone is ready.")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.honeText)

                        Group {
                            if let shortcutDisplay = hotkey?.displayString {
                                Text("**\(profileName)** is set up on **\(shortcutDisplay)**.")
                            } else {
                                Text("**\(profileName)** is ready to go.")
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color.honeText.opacity(0.6))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("How to use it")
                        successStep(n: 1, text: "Select any text in any app")
                        successStep(n: 2, text: "Press \(hotkey?.displayString ?? "your shortcut")")
                        successStep(n: 3, text: "Paste the rewrite with ⌘V")
                    }
                }

                Spacer()

                HStack {
                    Button("Manage Profiles") {
                        onDismiss()
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.honeMuted)

                    Spacer()

                    Button("Done") {
                        onDismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            MenuBarTipService.shared.show()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.honeAction)
                    .controlSize(.large)
                }
            }
            .padding(44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.honeLinen)
        }
        .frame(width: 660, height: 500)
    }

    func successStep(n: Int, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.honeAccent.opacity(0.18))
                    .frame(width: 22, height: 22)
                Text("\(n)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAction)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color.honeText.opacity(0.7))
        }
    }

    // MARK: Shared Helpers

    func heading(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.honeText)
            Text(sub)
                .font(.system(size: 13))
                .foregroundColor(Color.honeSubtext.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.honeAction)
            .textCase(.uppercase)
            .tracking(0.6)
    }

    func navRow(back: @escaping () -> Void, next: @escaping () -> Void, nextLabel: String, nextEnabled: Bool) -> some View {
        HStack {
            Button("Back", action: back)
                .buttonStyle(.plain)
                .foregroundColor(Color.honeMuted)
            Spacer()
            Button(nextLabel, action: next)
                .buttonStyle(.borderedProminent)
                .tint(Color.honeAction)
                .controlSize(.large)
                .disabled(!nextEnabled)
        }
    }

    // MARK: Finish

    private func finish() {
        let prompt = selectedTemplate == .custom ? profilePrompt : (selectedTemplate?.prompt ?? profilePrompt)
        let profile = Profile(
            name: profileName.trimmingCharacters(in: .whitespaces),
            prompt: prompt.trimmingCharacters(in: .whitespaces),
            hotkey: hotkey
        )
        appState.addProfile(profile)
        appState.completeOnboarding()
        HotkeyService.shared.registerAll(profiles: appState.profiles)
        // Skip accessibility step if already granted
        if AXIsProcessTrusted() {
            withAnimation { step = 6 }
        } else {
            withAnimation { step = 5 }
        }
    }

    private func startAccessibilityPolling() {
        // Always cancel any existing timer before starting a new one —
        // calling this twice would orphan the first timer and it runs forever.
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil

        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard AXIsProcessTrusted() else { return }
            DispatchQueue.main.async {
                accessibilityGranted = true
                accessibilityTimer?.invalidate()
                accessibilityTimer = nil
                withAnimation { step = 6 }
            }
        }
    }
}

// MARK: - Onboarding Account Step

struct OnboardingAccountStep: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    @ObservedObject private var supabase = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var awaitingConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if supabase.isLoggedIn {
                alreadyLoggedIn
            } else if awaitingConfirmation {
                confirmationPending
            } else {
                loginForm
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.honeLinen)
    }

    var confirmationPending: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Check your email")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.honeText)
                    Text("We sent a confirmation link to \(email). Click it to verify your account.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.honeSubtext.opacity(0.55))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.honeAction)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(email)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.honeText)
                        Text("Awaiting verification")
                            .font(.system(size: 11))
                            .foregroundColor(Color.honeMuted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.honeAction.opacity(0.08)))
            }

            Spacer()

            HStack {
                Button("Back") {
                    awaitingConfirmation = false
                    isSignUp = false
                    errorMessage = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.honeMuted)
                Spacer()
                Text("Confirmed your email?")
                    .font(.system(size: 12))
                    .foregroundColor(Color.honeMuted)
                Button("Sign In") {
                    awaitingConfirmation = false
                    isSignUp = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.honeAction)
            }
        }
    }

    var alreadyLoggedIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.honeText)
                    Text("Your profiles will sync across all your devices.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.honeSubtext.opacity(0.55))
                }

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.honeAction)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signed in")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.honeText)
                        Text(supabase.currentUser?.email ?? "")
                            .font(.system(size: 12))
                            .foregroundColor(Color.honeMuted)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.honeAction.opacity(0.08)))
            }

            Spacer()

            HStack {
                Button("Back", action: onBack)
                    .buttonStyle(.plain)
                    .foregroundColor(Color.honeMuted)
                Spacer()
                Button("Continue") { onContinue() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.honeAction)
                    .controlSize(.large)
            }
        }
    }

    var loginForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isSignUp ? "Create an account" : "Sign in")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color.honeText)
                    Text("Sync your profiles and settings across devices. You can skip this and do it later in Settings.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.honeSubtext.opacity(0.55))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .font(.system(size: 13))
                    SecureField("Password (min. 6 characters)", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                Button(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Create one") {
                    withAnimation { isSignUp.toggle(); errorMessage = "" }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Color.honeAction)
            }

            Spacer()

            HStack {
                Button("Back", action: onBack)
                    .buttonStyle(.plain)
                    .foregroundColor(Color.honeMuted)
                Spacer()

                Button("Skip") { onContinue() }
                    .buttonStyle(.plain)
                    .foregroundColor(Color.honeMuted)
                    .padding(.trailing, 12)

                Button(isSignUp ? "Create Account" : "Sign In") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.honeAction)
                .controlSize(.large)
                .disabled(email.isEmpty || password.count < 6 || isLoading)

                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = ""
        do {
            if isSignUp {
                let loggedIn = try await supabase.signUp(email: email, password: password)
                if !loggedIn {
                    isLoading = false
                    awaitingConfirmation = true
                    return
                }
            } else {
                _ = try await supabase.signIn(email: email, password: password)
            }
            onContinue()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
