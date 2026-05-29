import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var hasCompletedOnboarding: Bool = false
    @Published var autoPaste: Bool = false {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "hone.autoPaste") }
    }
    @Published var userEmail: String = "" {
        didSet { UserDefaults.standard.set(userEmail, forKey: "hone.userEmail") }
    }

    private let profilesKey = "hone.profiles"
    private let onboardingKey = "hone.onboardingComplete"

    // Legacy accessor — used by RewriteService for the active profile's provider
    var apiKey: String {
        get { KeychainService.shared.load() ?? "" }
        set { KeychainService.shared.save(newValue) }
    }

    func apiKey(for provider: AIProvider) -> String {
        KeychainService.shared.load(for: provider) ?? ""
    }

    func setApiKey(_ key: String, for provider: AIProvider) {
        KeychainService.shared.save(key, for: provider)
    }

    init() {
        loadProfiles()
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingKey)
        autoPaste = UserDefaults.standard.bool(forKey: "hone.autoPaste")
        userEmail = UserDefaults.standard.string(forKey: "hone.userEmail") ?? ""
        Task { await RemoteTemplateService.shared.fetch() }
    }

    func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data)
        else { return }
        profiles = decoded
    }

    func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        UserDefaults.standard.set(data, forKey: profilesKey)
    }

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        saveProfiles()
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingKey)
    }
}
