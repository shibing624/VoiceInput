import Foundation

final class LLMRefiner {
    private let systemPrompt = """
        You are a speech recognition post-processor. Fix ONLY obvious speech-to-text errors:
        - Chinese homophone errors (e.g. wrong tones)
        - English technical terms misrecognized as Chinese (e.g. "pei sen"->"Python", "jie sen"->"JSON")
        - Clear word boundary errors
        Do NOT rewrite, rephrase, polish, add punctuation changes, or remove any content that appears correct.
        If the input looks correct, return it EXACTLY as-is.
        Return ONLY the corrected text, nothing else.
        """

    func refine(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {
        let defaults = UserDefaults.standard
        let baseURL = defaults.string(forKey: DefaultsKey.llmAPIBaseURL) ?? "https://api.openai.com/v1"
        let apiKey = defaults.string(forKey: DefaultsKey.llmAPIKey) ?? ""
        let model = defaults.string(forKey: DefaultsKey.llmModel) ?? "gpt-4o-mini"

        guard !apiKey.isEmpty else {
            completion(.failure(LLMError.noAPIKey))
            return
        }

        let urlString = baseURL.hasSuffix("/") ? "\(baseURL)chat/completions" : "\(baseURL)/chat/completions"
        guard let url = URL(string: urlString) else {
            completion(.failure(LLMError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
            "temperature": 0.1,
            "max_tokens": 2048,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(.failure(LLMError.invalidResponse))
                return
            }

            completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
        }.resume()
    }

    var isConfigured: Bool {
        let key = UserDefaults.standard.string(forKey: DefaultsKey.llmAPIKey) ?? ""
        return !key.isEmpty
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: DefaultsKey.llmEnabled)
    }
}

enum LLMError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "API Key not configured"
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid response from API"
        }
    }
}
