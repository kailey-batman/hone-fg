import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case anthropic
    case openai
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Claude"
        case .openai:    return "ChatGPT"
        case .google:    return "Gemini"
        }
    }

    var companyName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai:    return "OpenAI"
        case .google:    return "Google"
        }
    }

    var icon: String {
        switch self {
        case .anthropic: return "sparkles"
        case .openai:    return "brain"
        case .google:    return "globe"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openai:    return "sk-..."
        case .google:    return "AIza..."
        }
    }

    var keychainAccount: String {
        return "\(rawValue)-api-key"
    }

    var model: String {
        switch self {
        case .anthropic: return "claude-haiku-4-5"
        case .openai:    return "gpt-4o-mini"
        case .google:    return "gemini-1.5-flash"
        }
    }

    var docsURL: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai:    return URL(string: "https://platform.openai.com/api-keys")!
        case .google:    return URL(string: "https://aistudio.google.com/app/apikey")!
        }
    }
}
