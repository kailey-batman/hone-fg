import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedProfileID: UUID?
    @State private var showNewProfile = false

    private let apiKeyID   = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let accountID  = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 620, minHeight: 440)
        .sheet(isPresented: $showNewProfile) {
            NewProfileSheet(isPresented: $showNewProfile) { profile in
                appState.addProfile(profile)
                HotkeyService.shared.registerAll(profiles: appState.profiles)
                selectedProfileID = profile.id
            }
        }
    }

    // MARK: Sidebar

    var sidebar: some View {
        VStack(spacing: 0) {
            // Profiles section
            VStack(alignment: .leading, spacing: 2) {
                Text("Profiles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAccent.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                ForEach(appState.profiles) { profile in
                    sidebarRow(
                        isSelected: selectedProfileID == profile.id,
                        label: profile.name,
                        badge: profile.hotkey?.displayString
                    ) {
                        selectedProfileID = profile.id
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteProfile(profile)
                        } label: {
                            Label("Delete Profile", systemImage: "trash")
                        }
                    }
                }
            }

            // Account section
            VStack(alignment: .leading, spacing: 2) {
                Text("Account")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAccent.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                sidebarRow(
                    isSelected: selectedProfileID == accountID,
                    label: "Account",
                    icon: "person.circle",
                    badge: nil
                ) {
                    selectedProfileID = accountID
                }

                if Config.builtInAPIKey == nil {
                    sidebarRow(
                        isSelected: selectedProfileID == apiKeyID,
                        label: "API Keys",
                        icon: "key.fill",
                        badge: nil
                    ) {
                        selectedProfileID = apiKeyID
                    }
                }
            }

            // General section
            VStack(alignment: .leading, spacing: 2) {
                Text("General")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAccent.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(Color.honeMuted)
                        .frame(width: 16)
                    Text("Auto-paste")
                        .font(.system(size: 12))
                        .foregroundColor(Color.honeMuted)
                    Spacer()
                    Toggle("", isOn: $appState.autoPaste)
                        .toggleStyle(.switch)
                        .scaleEffect(0.75)
                        .labelsHidden()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

                if Config.builtInAPIKey != nil {
                    EmailSettingRow()
                        .environmentObject(appState)
                    UsageTrackingRow()
                }
            }

            Spacer()

            // Bottom add button
            Divider().opacity(0.3)
            HStack {
                Button {
                    showNewProfile = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.honeAccent)
                }
                .buttonStyle(.plain)
                .help("New Profile")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 190)
        .background(Color.honeBase)
        .onAppear {
            if selectedProfileID == nil {
                selectedProfileID = appState.profiles.first?.id ?? accountID
            }
        }
    }

    func sidebarRow(isSelected: Bool, label: String, icon: String? = nil, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.honeBase : Color.honeAccent)
                        .frame(width: 16)
                } else {
                    Circle()
                        .fill(isSelected ? Color.honeBase : Color.honeAccent)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color.honeBase : .white)
                    .lineLimit(1)
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? Color.honeBase.opacity(0.7) : Color.honeMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.honeAccent : Color.clear)
            )
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    func deleteProfile(_ profile: Profile) {
        HotkeyService.shared.unregister(profileID: profile.id)
        appState.deleteProfile(profile)
        selectedProfileID = appState.profiles.first?.id ?? apiKeyID
    }

    func profileSidebarRow(_ profile: Profile) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.honeAccent)
                .frame(width: 7, height: 7)
            Text(profile.name)
                .font(.system(size: 13))
            Spacer()
            if let hotkey = profile.hotkey {
                Text(hotkey.displayString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Detail

    @ViewBuilder
    var detail: some View {
        if selectedProfileID == accountID {
            AccountSettingsView()
                .environmentObject(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.honeLinen)
        } else if selectedProfileID == apiKeyID {
            ApiKeyView()
                .environmentObject(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.honeLinen)
        } else if let id = selectedProfileID,
                  let index = appState.profiles.firstIndex(where: { $0.id == id }) {
            VStack(spacing: 0) {
                ScrollView {
                    ProfileEditorView(profile: $appState.profiles[index])
                        .padding(28)
                        .onChange(of: appState.profiles[index]) { _ in
                            appState.saveProfiles()
                            HotkeyService.shared.registerAll(profiles: appState.profiles)
                        }
                }
                Divider()
                HStack {
                    Button(role: .destructive) {
                        deleteProfile(appState.profiles[index])
                    } label: {
                        Label("Delete Profile", systemImage: "trash")
                            .font(.callout)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.honeLinen)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundColor(Color.honeAccent.opacity(0.5))
                Text("Select a profile to edit")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.honeLinen)
        }
    }
}

// MARK: Profile Editor

struct ProfileEditorView: View {
    @Binding var profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Profile Name")
                TextField("e.g. Internal Slack", text: $profile.name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Rewriting Instructions")
                Text("Tell Claude how to rewrite selected text for this profile.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $profile.prompt)
                    .font(.callout)
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(Color.honeCard.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.honeAccent.opacity(0.3))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("AI Provider")
                Text("Which model rewrites text for this profile.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $profile.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        HStack(spacing: 6) {
                            Image(systemName: provider.icon)
                            Text(provider.displayName)
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Keyboard Shortcut")
                Text("Requires at least one modifier (⌘ ⌥ ⇧ ⌃). Avoid system shortcuts like ⌘W.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ShortcutRecorderView(hotkey: $profile.hotkey)
            }

            Spacer()
        }
    }

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.honeAction)
            .textCase(.uppercase)
            .tracking(0.6)
    }
}

// MARK: New Profile Sheet

struct NewProfileSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (Profile) -> Void

    @State private var name = ""
    @State private var prompt = ""
    @State private var selectedTemplate: ProfileTemplate? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("New Profile")
                    .font(.title2).fontWeight(.bold)
                    .foregroundColor(Color.honeText)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 20)

            // Built-in templates
            VStack(alignment: .leading, spacing: 8) {
                sheetLabel("Start from a template")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProfileTemplate.all) { template in
                            templateChip(template, isWorkspace: false)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(.bottom, 18)

            // Name
            VStack(alignment: .leading, spacing: 5) {
                sheetLabel("Profile name")
                TextField("e.g. Customer Reply", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.bottom, 14)

            // Prompt
            VStack(alignment: .leading, spacing: 5) {
                sheetLabel("Rewriting instructions")
                ZStack(alignment: .topLeading) {
                    if prompt.isEmpty {
                        Text("Tell Claude how to rewrite selected text for this profile.")
                            .foregroundColor(Color.honeSubtext.opacity(0.3))
                            .font(.callout)
                            .padding(8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $prompt)
                        .font(.callout)
                        .frame(height: 110)
                        .scrollContentBackground(.hidden)
                }
                .padding(4)
                .background(Color.honeCard.opacity(0.7))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.honeAccent.opacity(0.3)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.bottom, 20)

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Button("Add Profile") {
                    onAdd(Profile(
                        name: name.trimmingCharacters(in: .whitespaces),
                        prompt: prompt.trimmingCharacters(in: .whitespaces)
                    ))
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.honeAction)
                .disabled(name.isEmpty || prompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 480, height: 440)
        .background(Color.honeLinen.ignoresSafeArea())
    }

    func sheetLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Color.honeAction)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    func templateChip(_ template: ProfileTemplate, isWorkspace: Bool) -> some View {
        let isSelected = selectedTemplate == template
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                selectedTemplate = template
                if name.isEmpty || ProfileTemplate.all.map(\.name).contains(name) {
                    name = template.name == "Custom" ? "" : template.name
                }
                if template != .custom {
                    prompt = template.prompt
                } else {
                    prompt = ""
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: template.icon)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white : (isWorkspace ? Color.honeAction : Color.honeAction))
                Text(template.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color.honeText)
                if isWorkspace {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 9))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : Color.honeAction.opacity(0.5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isSelected ? Color.honeAction : (isWorkspace ? Color.honeHighlight : Color.honeAccent.opacity(0.13)))
                    .overlay(
                        Capsule().stroke(
                            isSelected ? Color.clear : (isWorkspace ? Color.honeAction.opacity(0.3) : Color.honeAccent.opacity(0.25)),
                            lineWidth: 1
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: Email Setting Row (FG Version only)

struct EmailSettingRow: View {
    @EnvironmentObject var appState: AppState
    @State private var editing = false
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "envelope")
                    .font(.system(size: 11))
                    .foregroundColor(Color.honeMuted)
                    .frame(width: 16)
                if editing {
                    TextField("you@fieldguide.io", text: $draft, onCommit: save)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                    Button("Save", action: save)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.honeAction)
                        .controlSize(.small)
                        .disabled(!draft.contains("@"))
                } else {
                    Text(appState.userEmail.isEmpty ? "No email set" : appState.userEmail)
                        .font(.system(size: 11))
                        .foregroundColor(appState.userEmail.isEmpty ? Color.honeMuted.opacity(0.5) : Color.honeMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Edit") {
                        draft = appState.userEmail
                        editing = true
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(Color.honeAccent.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
        }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        if trimmed.contains("@") {
            appState.userEmail = trimmed
        }
        editing = false
    }
}

// MARK: Usage Tracking Row (FG Version only)

struct UsageTrackingRow: View {
    @AppStorage("hone.analyticsEnabled") private var analyticsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 11))
                    .foregroundColor(Color.honeMuted)
                    .frame(width: 16)
                Text("Usage tracking")
                    .font(.system(size: 12))
                    .foregroundColor(Color.honeMuted)
                Spacer()
                Toggle("", isOn: $analyticsEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.75)
                    .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)

            Text("Tracks: email, voice name, prompt, word counts. No text content is ever sent.")
                .font(.system(size: 10))
                .foregroundColor(Color.honeMuted.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.bottom, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: API Key View — Connected Services

struct ApiKeyView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CONNECTED SERVICES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.honeAction)
                        .tracking(0.6)
                    Text("Add an API key for each provider you want to use. Keys are stored in your Mac's Keychain.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }

                ForEach(AIProvider.allCases) { provider in
                    ProviderKeyRow(provider: provider)
                        .environmentObject(appState)
                }

                Spacer()
            }
            .padding(28)
        }
    }
}

struct ProviderKeyRow: View {
    @EnvironmentObject var appState: AppState
    let provider: AIProvider

    @State private var apiKey = ""
    @State private var saved = false
    @State private var isRevealed = false

    var isConnected: Bool { !appState.apiKey(for: provider).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isConnected ? Color.honeAction.opacity(0.15) : Color.honeAccent.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: provider.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isConnected ? Color.honeAction : Color.honeMuted)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.honeText)
                    Text(provider.companyName)
                        .font(.system(size: 11))
                        .foregroundColor(Color.honeMuted)
                }
                Spacer()
                if isConnected {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.honeAction)
                }
            }

            // Key field + save
            HStack(spacing: 8) {
                if isRevealed {
                    TextField(provider.keyPlaceholder, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                } else {
                    SecureField(provider.keyPlaceholder, text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.callout, design: .monospaced))
                }
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundColor(Color.honeMuted)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide key" : "Show key")

                Button(saved ? "Saved" : "Save") {
                    appState.setApiKey(apiKey.trimmingCharacters(in: .whitespaces), for: provider)
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { saved = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(saved ? Color.honeAction.opacity(0.6) : Color.honeAction)
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).count < 8)
            }

            Link("Get a key at \(provider.companyName.lowercased()) →", destination: provider.docsURL)
                .font(.system(size: 11))
                .foregroundColor(Color.honeAccent)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.honeCard.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isConnected ? Color.honeAction.opacity(0.25) : Color.honeAccent.opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear {
            apiKey = appState.apiKey(for: provider)
        }
    }
}

// MARK: Account Settings View

struct AccountSettingsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var supabase = SupabaseService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showConfirmSignOut = false
    @State private var awaitingConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if supabase.isLoggedIn {
                    loggedInView
                } else if awaitingConfirmation {
                    confirmationPendingView
                } else {
                    loginView
                }
            }
            .padding(28)
        }
    }

    var confirmationPendingView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CHECK YOUR EMAIL")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAction)
                    .tracking(0.6)
                Text("We sent a confirmation link to \(email). Click it to verify your account, then come back and sign in.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.honeAction.opacity(0.7))
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
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.honeCard.opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.honeAction.opacity(0.2), lineWidth: 1))
            )

            Button("Back to Sign In") {
                awaitingConfirmation = false
                isSignUp = false
                errorMessage = ""
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(Color.honeAction)
        }
    }

    // MARK: Logged in

    var loggedInView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ACCOUNT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAction)
                    .tracking(0.6)
                Text("Your profiles and settings sync automatically across devices.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.honeAction.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color.honeAction)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.currentUser?.email ?? "")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.honeText)
                        HStack(spacing: 4) {
                            if supabase.isSyncing {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                Text("Syncing...")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.honeMuted)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.honeAction)
                                Text("Synced")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.honeMuted)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.honeCard.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.honeAction.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("SYNCED DATA")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAction)
                    .tracking(0.6)

                syncRow(icon: "doc.text.fill", label: "Profiles", detail: "\(appState.profiles.count) profile\(appState.profiles.count == 1 ? "" : "s")")
                syncRow(icon: "keyboard", label: "Shortcuts", detail: "Included with profiles")
                syncRow(icon: "gearshape", label: "Settings", detail: "Auto-paste preference")
            }

            Button {
                showConfirmSignOut = true
            } label: {
                Text("Sign Out")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .confirmationDialog("Sign out of Hone?", isPresented: $showConfirmSignOut) {
                Button("Sign Out", role: .destructive) {
                    supabase.signOut()
                }
            } message: {
                Text("Your profiles will remain on this device but won't sync until you sign back in.")
            }
        }
    }

    func syncRow(icon: String, label: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color.honeAction)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.honeText)
            Spacer()
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(Color.honeMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.honeCard.opacity(0.4))
        )
    }

    // MARK: Login / Sign up

    var loginView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isSignUp ? "CREATE ACCOUNT" : "SIGN IN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.honeAction)
                    .tracking(0.6)
                Text(isSignUp
                     ? "Create an account to sync your profiles and settings across devices."
                     : "Sign in to sync your profiles and settings across all your devices.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .font(.system(size: 13))

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button(isSignUp ? "Create Account" : "Sign In") {
                    Task { await submit() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.honeAction)
                .disabled(email.isEmpty || password.count < 6 || isLoading)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Spacer()

                Button(isSignUp ? "Already have an account?" : "Create an account") {
                    withAnimation { isSignUp.toggle(); errorMessage = "" }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Color.honeAction)
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
                    // Confirmation email sent — show waiting state
                    isLoading = false
                    awaitingConfirmation = true
                    return
                }
                // Email confirmation disabled — logged in immediately
                appState.pushToSupabase()
            } else {
                _ = try await supabase.signIn(email: email, password: password)
            }
            await appState.syncFromSupabase()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
