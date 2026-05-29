import Foundation

enum RewriteError: Error, LocalizedError {
    case noTextSelected
    case noApiKey(AIProvider)
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noTextSelected:       return "No text selected"
        case .noApiKey(let p):      return "\(p.displayName) API key not set — open Settings to add one"
        case .apiError(let msg):    return "API error: \(msg)"
        case .parseError:           return "Couldn't parse API response"
        }
    }
}

class AIService {
    static let shared = AIService()

    func rewrite(text: String, systemPrompt: String, provider: AIProvider, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw RewriteError.noApiKey(provider) }

        switch provider {
        case .anthropic: return try await callAnthropic(text: text, systemPrompt: systemPrompt, apiKey: apiKey)
        case .openai:    return try await callOpenAI(text: text, systemPrompt: systemPrompt, apiKey: apiKey)
        case .google:    return try await callGoogle(text: text, systemPrompt: systemPrompt, apiKey: apiKey)
        }
    }

    // MARK: - Anthropic

    private func callAnthropic(text: String, systemPrompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey,                forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01",          forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model":      AIProvider.anthropic.model,
            "max_tokens": 1024,
            "system":     systemPrompt,
            "messages":   [["role": "user", "content": "Rewrite this:\n\n\(text)"]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data)

        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let result  = content.first?["text"] as? String
        else { throw RewriteError.parseError }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OpenAI

    private func callOpenAI(text: String, systemPrompt: String, apiKey: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)",    forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model":      AIProvider.openai.model,
            "max_tokens": 1024,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": "Rewrite this:\n\n\(text)"]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data)

        guard let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let result  = message["content"] as? String
        else { throw RewriteError.parseError }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Google Gemini

    private func callGoogle(text: String, systemPrompt: String, apiKey: String) async throws -> String {
        let model = AIProvider.google.model
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                ["parts": [["text": "Rewrite this:\n\n\(text)"]]]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try checkHTTP(response, data)

        guard let json        = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates  = json["candidates"] as? [[String: Any]],
              let content     = candidates.first?["content"] as? [String: Any],
              let parts       = content["parts"] as? [[String: Any]],
              let result      = parts.first?["text"] as? String
        else { throw RewriteError.parseError }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Shared

    private func checkHTTP(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown error"
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw RewriteError.apiError("HTTP \(code) — \(body)")
        }
    }
}

// Keep old name working so nothing else breaks during transition
typealias ClaudeService = AIService
