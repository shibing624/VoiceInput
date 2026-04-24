import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var diagnosticsAccessibilityItem: NSMenuItem!
    private var diagnosticsLastTriggerItem: NSMenuItem!
    private var languageItem: NSMenuItem!
    private var languageMenu: NSMenu!

    // MARK: - Callbacks (set by AppDelegate)
    var onDiagnosticsRefreshRequested: (() -> Void)?
    var onRecordingInputRequested: (() -> Void)?
    var onLanguageChanged: ((String) -> Void)?
    var onLLMToggled: ((Bool) -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onQuit: (() -> Void)?

    private let languages: [(title: String, code: String)] = [
        ("English", "en-US"),
        ("Simplified Chinese", "zh-CN"),
        ("Traditional Chinese", "zh-TW"),
        ("Japanese", "ja-JP"),
        ("Korean", "ko-KR"),
    ]

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform",
                                   accessibilityDescription: "VoiceInput")
        }

        let menu = NSMenu()
        menu.delegate = self

        let recordingInputItem = NSMenuItem(
            title: "Recording Input Box...",
            action: #selector(openRecordingInput(_:)),
            keyEquivalent: ""
        )
        recordingInputItem.target = self
        menu.addItem(recordingInputItem)

        menu.addItem(NSMenuItem.separator())

        diagnosticsAccessibilityItem = NSMenuItem(title: "Accessibility: checking...", action: nil, keyEquivalent: "")
        diagnosticsAccessibilityItem.isEnabled = false
        menu.addItem(diagnosticsAccessibilityItem)

        diagnosticsLastTriggerItem = NSMenuItem(title: "Last trigger: none", action: nil, keyEquivalent: "")
        diagnosticsLastTriggerItem.isEnabled = false
        menu.addItem(diagnosticsLastTriggerItem)

        menu.addItem(NSMenuItem.separator())

        languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageMenu = NSMenu()
        let selectedLanguage = UserDefaults.standard.string(forKey: DefaultsKey.selectedLanguage) ?? "zh-CN"
        for language in languages {
            let item = NSMenuItem(title: language.title,
                                  action: #selector(languageSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = language.code
            item.state = language.code == selectedLanguage ? .on : .off
            languageMenu.addItem(item)
        }
        languageItem.submenu = languageMenu
        menu.addItem(languageItem)

        // ── LLM Refinement submenu ─────────────────────────────────────────
        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()

        let toggleItem = NSMenuItem(title: "Enable",
                                    action: #selector(toggleLLM(_:)),
                                    keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = UserDefaults.standard.bool(forKey: DefaultsKey.llmEnabled) ? .on : .off
        llmMenu.addItem(toggleItem)

        llmMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(openSettings(_:)),
                                      keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(NSMenuItem.separator())

        // ── Quit ───────────────────────────────────────────────────────────
        let quitItem = NSMenuItem(title: "Quit VoiceInput",
                                  action: #selector(quitApp(_:)),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Recording state (called by AppDelegate)

    func menuWillOpen(_ menu: NSMenu) {
        onDiagnosticsRefreshRequested?()
    }

    func updateRecordingState(_ isRecording: Bool) {
        if isRecording {
            statusItem.button?.image = NSImage(
                systemSymbolName: "waveform.circle.fill",
                accessibilityDescription: "VoiceInput – Recording"
            )
        } else {
            statusItem.button?.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "VoiceInput"
            )
        }
    }

    func updateAccessibilityStatus(_ isGranted: Bool) {
        diagnosticsAccessibilityItem.title = "Accessibility: \(isGranted ? "granted" : "missing")"
    }

    func updateLastTrigger(_ trigger: FnKeyMonitor.TriggerSource?) {
        diagnosticsLastTriggerItem.title = "Last trigger: \(trigger?.menuLabel ?? "none")"
    }

    func updateSelectedLanguage(_ code: String) {
        for item in languageMenu.items {
            let itemCode = item.representedObject as? String
            item.state = itemCode == code ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func openRecordingInput(_ sender: NSMenuItem) {
        onRecordingInputRequested?()
    }

    @objc private func languageSelected(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        updateSelectedLanguage(code)
        onLanguageChanged?(code)
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        let newState = sender.state == .off
        sender.state = newState ? .on : .off
        UserDefaults.standard.set(newState, forKey: DefaultsKey.llmEnabled)
        onLLMToggled?(newState)
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        onSettingsRequested?()
    }

    @objc private func quitApp(_ sender: NSMenuItem) {
        onQuit?()
    }
}
