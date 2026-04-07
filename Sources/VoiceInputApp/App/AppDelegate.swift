import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar       = StatusBarController()
    private let floatingPanel   = FloatingPanel()
    private let audioRecorder   = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let fnKeyMonitor    = FnKeyMonitor()
    private let textInjector    = TextInjector()
    private let llmRefiner      = LLMRefiner()
    private var settingsWindow: SettingsWindow?

    private var isRecording = false
    private var lastTranscription = ""
    private var eventTapRetryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DefaultsKey.registerDefaults()

        // Request microphone & speech permissions (system dialogs, only on first launch)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SpeechRecognizer.requestAuthorization { _ in }

        // Setup status bar
        statusBar.setup()
        statusBar.onLanguageChanged = { [weak self] code in
            self?.speechRecognizer.setLanguage(code)
        }
        statusBar.onLLMToggled = { _ in
            // State stored in UserDefaults; no extra action needed here.
        }
        statusBar.onSettingsRequested = { [weak self] in
            self?.showSettings()
        }
        statusBar.onQuit = {
            NSApp.terminate(nil)
        }

        // Wire audio recorder
        audioRecorder.onRMSLevel = { [weak self] rms in
            self?.floatingPanel.updateRMS(rms)
        }
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            self?.speechRecognizer.appendAudioBuffer(buffer)
        }

        // Wire speech recognizer
        speechRecognizer.onPartialResult = { [weak self] text in
            self?.lastTranscription = text
            self?.floatingPanel.updateText(text)
        }
        speechRecognizer.onFinalResult = { [weak self] text in
            self?.lastTranscription = text
            self?.floatingPanel.updateText(text)
        }

        // Setup Fn / Right Command key monitoring
        setupFnMonitor()

        // Apply saved language
        let lang = UserDefaults.standard.string(forKey: DefaultsKey.selectedLanguage) ?? "zh-CN"
        speechRecognizer.setLanguage(lang)
    }

    // MARK: - Fn Monitor

    private func setupFnMonitor() {
        fnKeyMonitor.onFnDown = { [weak self] in self?.startVoiceInput() }
        fnKeyMonitor.onFnUp   = { [weak self] in self?.stopVoiceInput()  }

        if fnKeyMonitor.start() { return }

        // Event tap failed — Accessibility not granted yet.
        // Show the system prompt (fires once per install), then poll until granted.
        _ = FnKeyMonitor.checkAccessibility()

        eventTapRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if FnKeyMonitor.isAccessibilityGranted(), self.fnKeyMonitor.start() {
                timer.invalidate()
                self.eventTapRetryTimer = nil
            }
        }
    }

    // MARK: - Voice Input

    private func startVoiceInput() {
        guard !isRecording else { return }
        isRecording = true
        lastTranscription = ""

        statusBar.updateRecordingState(true)
        floatingPanel.updateText("")
        floatingPanel.showAnimated()

        speechRecognizer.startRecognition()
        do {
            try audioRecorder.startRecording()
        } catch {
            showAlert(title: "Recording Error", message: error.localizedDescription)
            isRecording = false
            statusBar.updateRecordingState(false)
            floatingPanel.hideAnimated()
        }
    }

    private func stopVoiceInput() {
        guard isRecording else { return }
        isRecording = false

        statusBar.updateRecordingState(false)
        audioRecorder.stopRecording()
        speechRecognizer.stopRecognition()

        let text = lastTranscription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            floatingPanel.hideAnimated()
            return
        }

        if llmRefiner.isEnabled && llmRefiner.isConfigured {
            floatingPanel.updateText("Refining…")
            llmRefiner.refine(text) { [weak self] result in
                DispatchQueue.main.async {
                    let finalText: String
                    switch result {
                    case .success(let refined): finalText = refined
                    case .failure:              finalText = text   // fallback
                    }
                    self?.floatingPanel.updateText(finalText)
                    self?.floatingPanel.hideAnimated {
                        self?.textInjector.inject(finalText)
                    }
                }
            }
        } else {
            floatingPanel.hideAnimated { [weak self] in
                self?.textInjector.inject(text)
            }
        }
    }

    // MARK: - Settings

    private func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Helpers

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText     = title
        alert.informativeText = message
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fnKeyMonitor.stop()
        audioRecorder.stopRecording()
        speechRecognizer.stopRecognition()
    }
}
