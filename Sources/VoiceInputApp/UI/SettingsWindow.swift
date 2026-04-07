import AppKit

final class SettingsWindow: NSWindow {
    private var apiBaseField: NSTextField!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    private var testButton: NSButton!
    private var saveButton: NSButton!
    private var statusLabel: NSTextField!

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "LLM Settings"
        center()
        isReleasedWhenClosed = false
        setupUI()
        loadSettings()
    }

    private func setupUI() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 260))
        contentView = container

        let labelWidth: CGFloat = 100
        let fieldX: CGFloat = 110
        let fieldWidth: CGFloat = 340
        var y: CGFloat = 210

        func addLabel(_ text: String, at yPos: CGFloat) {
            let label = NSTextField(labelWithString: text)
            label.frame = NSRect(x: 20, y: yPos, width: labelWidth, height: 22)
            label.alignment = .right
            label.font = NSFont.systemFont(ofSize: 13)
            container.addSubview(label)
        }

        addLabel("API Base URL:", at: y)
        apiBaseField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        apiBaseField.placeholderString = "https://api.openai.com/v1"
        apiBaseField.font = NSFont.systemFont(ofSize: 13)
        container.addSubview(apiBaseField)

        y -= 40
        addLabel("API Key:", at: y)
        apiKeyField = NSSecureTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.font = NSFont.systemFont(ofSize: 13)
        container.addSubview(apiKeyField)

        y -= 40
        addLabel("Model:", at: y)
        modelField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        modelField.placeholderString = "gpt-4o-mini"
        modelField.font = NSFont.systemFont(ofSize: 13)
        container.addSubview(modelField)

        y -= 50
        testButton = NSButton(title: "Test Connection", target: self, action: #selector(testConnection))
        testButton.frame = NSRect(x: fieldX, y: y, width: 130, height: 30)
        testButton.bezelStyle = .rounded
        container.addSubview(testButton)

        saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.frame = NSRect(x: fieldX + 140, y: y, width: 80, height: 30)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        container.addSubview(saveButton)

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: fieldX + 230, y: y + 4, width: 200, height: 22)
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        container.addSubview(statusLabel)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        apiBaseField.stringValue = defaults.string(forKey: DefaultsKey.llmAPIBaseURL) ?? ""
        apiKeyField.stringValue = defaults.string(forKey: DefaultsKey.llmAPIKey) ?? ""
        modelField.stringValue = defaults.string(forKey: DefaultsKey.llmModel) ?? ""
    }

    @objc private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(apiBaseField.stringValue, forKey: DefaultsKey.llmAPIBaseURL)
        defaults.set(apiKeyField.stringValue, forKey: DefaultsKey.llmAPIKey)
        defaults.set(modelField.stringValue, forKey: DefaultsKey.llmModel)
        statusLabel.stringValue = "Saved"
        statusLabel.textColor = .systemGreen
    }

    @objc private func testConnection() {
        statusLabel.stringValue = "Testing..."
        statusLabel.textColor = .secondaryLabelColor
        testButton.isEnabled = false

        let refiner = LLMRefiner()
        refiner.refine("Hello") { [weak self] result in
            DispatchQueue.main.async {
                self?.testButton.isEnabled = true
                switch result {
                case .success:
                    self?.statusLabel.stringValue = "Connection OK"
                    self?.statusLabel.textColor = .systemGreen
                case .failure(let error):
                    self?.statusLabel.stringValue = "Failed: \(error.localizedDescription)"
                    self?.statusLabel.textColor = .systemRed
                }
            }
        }
    }
}
