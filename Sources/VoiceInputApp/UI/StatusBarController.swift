import AppKit

final class StatusBarController {
    private var statusItem: NSStatusItem!
    private var languageMenu: NSMenu!

    // MARK: - Callbacks (set by AppDelegate)
    var onLanguageChanged: ((String) -> Void)?
    var onLLMToggled: ((Bool) -> Void)?
    var onSettingsRequested: (() -> Void)?
    var onQuit: (() -> Void)?

    private let languages: [(title: String, code: String)] = [
        ("English",            "en-US"),
        ("Simplified Chinese", "zh-CN"),
        ("Traditional Chinese","zh-TW"),
        ("Japanese",           "ja-JP"),
        ("Korean",             "ko-KR"),
    ]

    // MARK: - Setup

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform",
                                   accessibilityDescription: "VoiceInput")
        }

        let menu = NSMenu()

        // ── Language submenu ───────────────────────────────────────────────
        let languageItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        languageMenu = NSMenu()
        let selectedLang = UserDefaults.standard.string(forKey: DefaultsKey.selectedLanguage) ?? "zh-CN"
        for lang in languages {
            let item = NSMenuItem(title: lang.title,
                                  action: #selector(languageSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = lang.code
            if lang.code == selectedLang { item.state = .on }
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

    // MARK: - Actions

    @objc private func languageSelected(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        for item in languageMenu.items { item.state = .off }
        sender.state = .on
        UserDefaults.standard.set(code, forKey: DefaultsKey.selectedLanguage)
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

    // MARK: - Helpers

    private func icon(_ symbolName: String) -> NSImage? {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }
}
