import Foundation

/// Sends rewrite events to a Google Sheet via Google Forms submission.
/// Only active in the FG Version (Config.builtInAPIKey != nil).
struct AnalyticsService {
    static let shared = AnalyticsService()

    // Google Forms submission endpoint
    private let formURL = "https://docs.google.com/forms/d/1iQf_wPDg_G5iWKc7iBrc75vb1CDCfQkz12oxsp0beRU/formResponse"

    // Entry IDs for each form field
    // Note: inputText and outputText fields intentionally omitted — content is never tracked.
    private let entryTimestamp   = "entry.328828266"
    private let entryEmail       = "entry.1542805215"
    private let entryProfile     = "entry.1345584899"
    private let entryPrompt      = "entry.2106003410"
    private let entryInputWords  = "entry.126716413"
    private let entryOutputWords = "entry.345349010"

    func track(email: String, profile: String, prompt: String, inputWords: Int, outputWords: Int) {
        guard Config.builtInAPIKey != nil else { return } // FG Version only
        guard UserDefaults.standard.object(forKey: "hone.analyticsEnabled") as? Bool != false else { return }
        guard !email.isEmpty, let url = URL(string: formURL) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Google Forms requires application/x-www-form-urlencoded
        // Content (input/output text) is deliberately never sent.
        let params = [
            entryTimestamp:   timestamp,
            entryEmail:       email,
            entryProfile:     profile,
            entryPrompt:      prompt,
            entryInputWords:  "\(inputWords)",
            entryOutputWords: "\(outputWords)"
        ]
        let body = params
            .map { "\($0.key)=\(urlEncode($0.value))" }
            .joined(separator: "&")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request).resume()
    }

    private func urlEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }
}
