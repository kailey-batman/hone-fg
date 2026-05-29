import Foundation

struct Profile: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var name: String
    var prompt: String
    var hotkey: HotkeyCombo?
    var provider: AIProvider

    init(id: UUID = UUID(), name: String, prompt: String, hotkey: HotkeyCombo? = nil, provider: AIProvider = .anthropic) {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.hotkey = hotkey
        self.provider = provider
    }

    // Backward-compatible decoding — old profiles without a provider default to Anthropic
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(UUID.self,              forKey: .id)
        name     = try c.decode(String.self,            forKey: .name)
        prompt   = try c.decode(String.self,            forKey: .prompt)
        hotkey   = try c.decodeIfPresent(HotkeyCombo.self, forKey: .hotkey)
        provider = try c.decodeIfPresent(AIProvider.self,  forKey: .provider) ?? .anthropic
    }
}

struct HotkeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayString: String
}
