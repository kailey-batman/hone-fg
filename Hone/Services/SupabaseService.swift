import Foundation
import Combine

// MARK: - Models

struct SupabaseUser: Codable {
    let id: String
    let email: String?
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken  = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct RemoteProfile: Codable {
    var id: String?
    var userId: String?
    var name: String
    var prompt: String
    var provider: String
    var hotkeyCode: Int?
    var hotkeyModifiers: Int?
    var hotkeyDisplay: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case name
        case prompt
        case provider
        case hotkeyCode    = "hotkey_code"
        case hotkeyModifiers = "hotkey_modifiers"
        case hotkeyDisplay = "hotkey_display"
        case sortOrder     = "sort_order"
    }
}

struct RemoteSettings: Codable {
    var userId: String?
    var autoPaste: Bool

    enum CodingKeys: String, CodingKey {
        case userId    = "user_id"
        case autoPaste = "auto_paste"
    }
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:  return "Incorrect email or password."
        case .emailAlreadyExists:  return "An account with that email already exists."
        case .networkError:        return "No internet connection."
        case .unknown(let msg):    return msg
        }
    }
}

// MARK: - Service

@MainActor
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()

    private let projectURL = "https://ybrtbmambwdfeksjbvyi.supabase.co"
    private let publishableKey = "sb_publishable_glexRh8zrpeNo39OWB1eDw_XzobskKE"
    private let tokenKey = "hone.supabase.accessToken"
    private let refreshKey = "hone.supabase.refreshToken"
    private let userIDKey = "hone.supabase.userID"
    private let userEmailKey = "hone.supabase.email"

    @Published var currentUser: SupabaseUser? = nil
    @Published var isSyncing = false

    var isLoggedIn: Bool { currentUser != nil }

    init() {
        // Restore session from keychain on launch
        if let token = KeychainService.shared.loadRaw(key: tokenKey),
           let userID = UserDefaults.standard.string(forKey: userIDKey),
           let email = UserDefaults.standard.string(forKey: userEmailKey) {
            currentUser = SupabaseUser(id: userID, email: email)
            _ = token // loaded for later use in requests
        }
    }

    // MARK: Auth

    func signUp(email: String, password: String) async throws -> SupabaseSession {
        let body: [String: Any] = ["email": email, "password": password]
        let session: SupabaseSession = try await request(
            path: "/auth/v1/signup",
            method: "POST",
            body: body,
            authenticated: false
        )
        saveSession(session)
        return session
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        let body: [String: Any] = ["email": email, "password": password]
        let session: SupabaseSession = try await request(
            path: "/auth/v1/token?grant_type=password",
            method: "POST",
            body: body,
            authenticated: false
        )
        saveSession(session)
        return session
    }

    func signOut() {
        KeychainService.shared.deleteRaw(key: tokenKey)
        KeychainService.shared.deleteRaw(key: refreshKey)
        UserDefaults.standard.removeObject(forKey: userIDKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        currentUser = nil
    }

    // MARK: Profiles sync

    func pushProfiles(_ profiles: [Profile]) async {
        guard isLoggedIn, let userID = currentUser?.id else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Delete all remote profiles for this user then re-insert
        // Simpler than diffing — profile count is small
        do {
            try await deleteAllProfiles(userID: userID)
            for (index, profile) in profiles.enumerated() {
                let remote = RemoteProfile(
                    id: profile.id.uuidString,
                    userId: userID,
                    name: profile.name,
                    prompt: profile.prompt,
                    provider: profile.provider.rawValue,
                    hotkeyCode: profile.hotkey.map { Int($0.keyCode) },
                    hotkeyModifiers: profile.hotkey.map { Int($0.carbonModifiers) },
                    hotkeyDisplay: profile.hotkey?.displayString,
                    sortOrder: index
                )
                try await upsertProfile(remote)
            }
        } catch {
            print("Supabase push error: \(error)")
        }
    }

    func pullProfiles() async -> [Profile]? {
        guard isLoggedIn else { return nil }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let remotes: [RemoteProfile] = try await requestData(
                path: "/rest/v1/profiles?order=sort_order.asc",
                method: "GET",
                body: nil,
                authenticated: true
            )
            return remotes.compactMap { Profile(from: $0) }
        } catch {
            print("Supabase pull profiles error: \(error)")
            return nil
        }
    }

    // MARK: Settings sync

    func pushSettings(autoPaste: Bool) async {
        guard isLoggedIn, let userID = currentUser?.id else { return }
        let settings = RemoteSettings(userId: userID, autoPaste: autoPaste)
        do {
            try await upsertSettings(settings)
        } catch {
            print("Supabase push settings error: \(error)")
        }
    }

    func pullSettings() async -> RemoteSettings? {
        guard isLoggedIn else { return nil }
        do {
            let results: [RemoteSettings] = try await requestData(
                path: "/rest/v1/user_settings?limit=1",
                method: "GET",
                body: nil,
                authenticated: true
            )
            return results.first
        } catch {
            print("Supabase pull settings error: \(error)")
            return nil
        }
    }

    // MARK: Private helpers

    private func deleteAllProfiles(userID: String) async throws {
        let _: Data = try await rawRequest(
            path: "/rest/v1/profiles?user_id=eq.\(userID)",
            method: "DELETE",
            body: nil,
            authenticated: true
        )
    }

    private func upsertProfile(_ profile: RemoteProfile) async throws {
        let _: Data = try await rawRequest(
            path: "/rest/v1/profiles",
            method: "POST",
            body: try JSONEncoder().encode(profile),
            authenticated: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
    }

    private func upsertSettings(_ settings: RemoteSettings) async throws {
        let _: Data = try await rawRequest(
            path: "/rest/v1/user_settings",
            method: "POST",
            body: try JSONEncoder().encode(settings),
            authenticated: true,
            extraHeaders: ["Prefer": "resolution=merge-duplicates"]
        )
    }

    private func saveSession(_ session: SupabaseSession) {
        KeychainService.shared.saveRaw(key: tokenKey, value: session.accessToken)
        KeychainService.shared.saveRaw(key: refreshKey, value: session.refreshToken)
        UserDefaults.standard.set(session.user.id, forKey: userIDKey)
        UserDefaults.standard.set(session.user.email ?? "", forKey: userEmailKey)
        currentUser = session.user
    }

    private func accessToken() -> String? {
        KeychainService.shared.loadRaw(key: tokenKey)
    }

    // MARK: Generic request

    private func request<T: Decodable>(
        path: String,
        method: String,
        body: [String: Any]?,
        authenticated: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        let bodyData = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        let data: Data = try await rawRequest(
            path: path, method: method, body: bodyData,
            authenticated: authenticated, extraHeaders: extraHeaders
        )
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Surface Supabase error messages
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["msg"] as? String ?? json["message"] as? String ?? json["error_description"] as? String {
                if msg.contains("already registered") { throw SupabaseError.emailAlreadyExists }
                if msg.contains("Invalid login") || msg.contains("invalid") { throw SupabaseError.invalidCredentials }
                throw SupabaseError.unknown(msg)
            }
            throw error
        }
    }

    private func requestData<T: Decodable>(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> T {
        let data: Data = try await rawRequest(
            path: path, method: method, body: body,
            authenticated: authenticated, extraHeaders: extraHeaders
        )
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func rawRequest(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let url = URL(string: projectURL + path) else {
            throw SupabaseError.unknown("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(publishableKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        if authenticated, let token = accessToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            req.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in extraHeaders { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            return data
        } catch {
            throw SupabaseError.networkError
        }
    }
}

// MARK: - Profile conversion

extension Profile {
    init?(from remote: RemoteProfile) {
        guard let idString = remote.id, let uuid = UUID(uuidString: idString) else { return nil }
        let hotkey: HotkeyCombo? = {
            guard let code = remote.hotkeyCode,
                  let mods = remote.hotkeyModifiers,
                  let display = remote.hotkeyDisplay else { return nil }
            return HotkeyCombo(keyCode: UInt32(code), carbonModifiers: UInt32(mods), displayString: display)
        }()
        self.init(
            id: uuid,
            name: remote.name,
            prompt: remote.prompt,
            hotkey: hotkey,
            provider: AIProvider(rawValue: remote.provider) ?? .anthropic
        )
    }
}
