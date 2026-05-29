import Foundation
import Combine

// MARK: - Remote Template Model

struct RemoteTemplate: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let prompt: String
    let icon: String

    static func == (lhs: RemoteTemplate, rhs: RemoteTemplate) -> Bool { lhs.id == rhs.id }

    /// Converts to a ProfileTemplate-compatible value for the UI
    func asProfileTemplate() -> ProfileTemplate {
        ProfileTemplate(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            tagline: tagline,
            prompt: prompt,
            icon: icon
        )
    }
}

struct RemoteTemplateBundle: Codable {
    let workspace: String
    let templates: [RemoteTemplate]
}

// MARK: - Service

@MainActor
class RemoteTemplateService: ObservableObject {
    static let shared = RemoteTemplateService()

    @Published var workspaceName: String = ""
    @Published var templates: [RemoteTemplate] = []
    @Published var isLoading = false
    @Published var lastError: String? = nil

    // Swap this URL for wherever you host the JSON.
    // A public GitHub Gist works great — see the sample JSON below.
    private let feedURL = URL(string: "https://gist.githubusercontent.com/kailey-batman/53b34c86bf6e1a98904de52ad4c929f1/raw/gistfile1.txt")!

    private let cacheKey = "hone.remoteTemplates"
    private let cacheWorkspaceKey = "hone.remoteWorkspaceName"

    private init() {
        loadCache()
    }

    func fetch() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        do {
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                lastError = "Server returned an error."
                return
            }
            let bundle = try JSONDecoder().decode(RemoteTemplateBundle.self, from: data)
            workspaceName = bundle.workspace
            templates = bundle.templates
            saveCache(data: data, workspaceName: bundle.workspace)
        } catch {
            lastError = "Could not load workspace templates."
        }
    }

    // MARK: - Cache

    private func saveCache(data: Data, workspaceName: String) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(workspaceName, forKey: cacheWorkspaceKey)
    }

    private func loadCache() {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let bundle = try? JSONDecoder().decode(RemoteTemplateBundle.self, from: data)
        else { return }
        workspaceName = bundle.workspace
        templates = bundle.templates
    }
}
