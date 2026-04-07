import Foundation

enum DefaultsKey {
    static let selectedLanguage = "selectedLanguage"
    static let llmEnabled = "llmEnabled"
    static let llmAPIBaseURL = "llmAPIBaseURL"
    static let llmAPIKey = "llmAPIKey"
    static let llmModel = "llmModel"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            selectedLanguage: "zh-CN",
            llmEnabled: false,
            llmAPIBaseURL: "https://api.openai.com/v1",
            llmAPIKey: "",
            llmModel: "gpt-4o-mini",
        ])
    }
}
