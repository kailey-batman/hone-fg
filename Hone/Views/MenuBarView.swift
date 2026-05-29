import SwiftUI
#if canImport(Sparkle)
import Sparkle
#endif

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var rewriteService: RewriteService

    var body: some View {
        VStack(spacing: 0) {
            header
            profileList
            footer
        }
        .frame(width: 300)
        .background(Color.honeBase)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Header

    var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 6) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.honeAccent)
                Text("Hone")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            statusBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    var statusBadge: some View {
        if rewriteService.isProcessing {
            HStack(spacing: 5) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                Text("Working...")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.honeMuted)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.honeSurface))
        } else if !rewriteService.statusMessage.isEmpty {
            let isError = rewriteService.statusMessage.lowercased().contains("wrong") ||
                          rewriteService.statusMessage.lowercased().contains("invalid") ||
                          rewriteService.statusMessage.lowercased().contains("no internet") ||
                          rewriteService.statusMessage.lowercased().contains("limit") ||
                          rewriteService.statusMessage.lowercased().contains("down")
            Text(rewriteService.statusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isError ? .red.opacity(0.85) : .honeAccent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(isError ? Color.red.opacity(0.1) : Color.honeAccent.opacity(0.15)))
                .transition(.opacity)
        }
    }

    // MARK: Profile List

    var profileList: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.honeSurface)

            if appState.profiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.honeMuted)
                    Text("No profiles yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.honeMuted)
                    Text("Open Settings to create one")
                        .font(.system(size: 11))
                        .foregroundColor(.honeMuted.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                VStack(spacing: 2) {
                    ForEach(appState.profiles) { profile in
                        ProfileRow(profile: profile)
                            .environmentObject(appState)
                            .environmentObject(rewriteService)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }

            Divider().overlay(Color.honeSurface)
        }
    }

    // MARK: Footer

    var footer: some View {
        HStack(spacing: 12) {
            SettingsLink {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                    Text("Settings")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.honeMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.honeSurface)
                )
            }
            .buttonStyle(.plain)

            Spacer()

            #if canImport(Sparkle)
            Button {
                NSApp.sendAction(#selector(SPUStandardUpdaterController.checkForUpdates(_:)), to: nil, from: nil)
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13))
                    .foregroundColor(.honeMuted)
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.honeSurface)
                    )
            }
            .buttonStyle(.plain)
            .help("Check for Updates")
            #endif

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.honeMuted)
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.honeSurface)
                    )
            }
            .buttonStyle(.plain)
            .help("Quit Hone")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: Profile Row

struct ProfileRow: View {
    let profile: Profile
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var rewriteService: RewriteService
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Accent dot
            Circle()
                .fill(Color.honeAccent)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                if let hotkey = profile.hotkey {
                    Text(hotkey.displayString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.honeMuted)
                }
            }

            Spacer()

            Button {
                RewriteService.shared.rewrite(profile: profile, apiKey: appState.apiKey)
            } label: {
                Text("Run")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(rewriteService.isProcessing ? .honeMuted : Color.honeBase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(rewriteService.isProcessing ? Color.honeSurface : Color.honeAccent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(rewriteService.isProcessing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(ProfileCardStyle(isHovered: isHovered))
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
