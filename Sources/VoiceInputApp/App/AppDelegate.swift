import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum RecordingDestination {
        case inject
        case inputPanel
    }

    private let statusBar = StatusBarController()
    private let floatingPanel = FloatingPanel()
    private let recordingInputPanel = RecordingInputPanel()
    private let audioRecorder = AudioRecorder()
    private let speechRecognizer = SpeechRecognizer()
    private let fnKeyMonitor = FnKeyMonitor()
    private let textInjector = TextInjector()
    private let llmRefiner = LLMRefiner()
    private var settingsWindow: SettingsWindow?

    private var isRecording = false
    private var recordingDestination: RecordingDestination?
    private var lastTranscription = ""
    private var eventTapRetryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        DefaultsKey.registerDefaults()

        // Request system permissions (dialogs only appear on first use)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        SpeechRecognizer.requestAuthorization { _ in }

        // Setup status bar
        statusBar.setup()
        statusBar.onDiagnosticsRefreshRequested = { [weak self] in
            self?.refreshDiagnostics()
        }
        statusBar.onRecordingInputRequested = { [weak self] in
            self?.showRecordingInputPanel()
        }
        statusBar.onLanguageChanged = { [weak self] code in
            self?.handleLanguageChange(code)
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

        recordingInputPanel.onToggleRecording = { [weak self] in
            self?.toggleRecordingInputPanelSession()
        }

        fnKeyMonitor.onTriggerDetected = { [weak self] source in
            self?.statusBar.updateLastTrigger(source)
        }

        // Wire audio recorder
        audioRecorder.onRMSLevel = { [weak self] rms in
            guard let self, self.recordingDestination == .inject else { return }
            self.floatingPanel.updateRMS(rms)
        }
        audioRecorder.onAudioBuffer = { [weak self] buffer in
            self?.handleAudioBuffer(buffer)
        }

        // Wire Apple Speech recognizer
        speechRecognizer.onPartialResult = { [weak self] text in
            self?.handlePartialTranscription(text)
        }
        speechRecognizer.onFinalResult = { [weak self] text in
            self?.handleFinalTranscription(text)
        }
        speechRecognizer.onError = { [weak self] error in
            self?.handleASRError(error.localizedDescription)
        }

        // Setup Fn / Right Command key monitoring
        setupFnMonitor()

        handleLanguageChange(currentLanguageCode, persist: false)
        statusBar.updateSelectedLanguage(currentLanguageCode)
        statusBar.updateLastTrigger(nil)
        refreshDiagnostics()
    }

    // MARK: - Fn Monitor

    private func setupFnMonitor() {
        fnKeyMonitor.onFnDown = { [weak self] in self?.startVoiceInput(destination: .inject) }
        fnKeyMonitor.onFnUp   = { [weak self] in self?.stopVoiceInput(for: .inject)  }

        let trusted = FnKeyMonitor.isAccessibilityGranted()
        statusBar.updateAccessibilityStatus(trusted)
        NSLog("[VoiceInput] Accessibility granted: %@", trusted ? "YES" : "NO")

        if fnKeyMonitor.start() {
            NSLog("[VoiceInput] Event tap created successfully")
            return
        }

        NSLog("[VoiceInput] Event tap failed — waiting for Accessibility permission")
        _ = FnKeyMonitor.checkAccessibility()

        eventTapRetryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let granted = FnKeyMonitor.isAccessibilityGranted()
            self.statusBar.updateAccessibilityStatus(granted)
            NSLog("[VoiceInput] Retry: Accessibility granted = %@", granted ? "YES" : "NO")
            if granted, self.fnKeyMonitor.start() {
                NSLog("[VoiceInput] Event tap created on retry")
                timer.invalidate()
                self.eventTapRetryTimer = nil
            }
        }
    }

    // MARK: - Voice Input

    private func startVoiceInput(destination: RecordingDestination) {
        guard !isRecording else { return }
        isRecording = true
        recordingDestination = destination
        lastTranscription = ""

        statusBar.updateRecordingState(true)
        if destination == .inject {
            floatingPanel.updateText("")
            floatingPanel.showAnimated()
        } else {
            recordingInputPanel.beginRecordingSession()
        }

        do {
            speechRecognizer.startRecognition()
            try audioRecorder.startRecording()
        } catch {
            recordingDestination = nil
            speechRecognizer.stopRecognition()
            recordingInputPanel.cancelRecordingSession()
            showAlert(title: "Recording Error", message: error.localizedDescription)
            isRecording = false
            statusBar.updateRecordingState(false)
            floatingPanel.hideAnimated()
        }
    }

    private func stopVoiceInput(for expectedDestination: RecordingDestination? = nil) {
        guard isRecording else { return }
        if let expectedDestination, recordingDestination != expectedDestination {
            return
        }

        isRecording = false

        statusBar.updateRecordingState(false)
        audioRecorder.stopRecording()
        speechRecognizer.stopRecognition()
        finishTranscription(lastTranscription)
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

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        speechRecognizer.appendAudioBuffer(buffer)
    }

    private func handlePartialTranscription(_ text: String) {
        lastTranscription = text

        switch recordingDestination {
        case .inject:
            floatingPanel.updateText(text)
        case .inputPanel:
            recordingInputPanel.updateDraftText(text)
        case .none:
            break
        }
    }

    private func handleFinalTranscription(_ text: String) {
        guard recordingDestination != nil else { return }
        finishTranscription(text)
    }

    private func finishTranscription(_ text: String) {
        let destination = recordingDestination
        recordingDestination = nil
        let finalText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        lastTranscription = finalText

        if destination == .inputPanel {
            recordingInputPanel.finishRecordingSession(with: finalText)
            return
        }

        guard !finalText.isEmpty else {
            floatingPanel.hideAnimated()
            return
        }

        floatingPanel.updateText(finalText)

        if llmRefiner.isEnabled && llmRefiner.isConfigured {
            floatingPanel.updateText("Refining…")
            llmRefiner.refine(finalText) { [weak self] result in
                DispatchQueue.main.async {
                    let refinedText: String
                    switch result {
                    case .success(let refined):
                        refinedText = refined
                    case .failure:
                        refinedText = finalText
                    }
                    self?.floatingPanel.updateText(refinedText)
                    self?.floatingPanel.hideAnimated {
                        self?.textInjector.inject(refinedText)
                    }
                }
            }
            return
        }

        floatingPanel.hideAnimated { [weak self] in
            self?.textInjector.inject(finalText)
        }
    }

    private func handleASRError(_ message: String) {
        let destination = recordingDestination
        let shouldShowAlert = isRecording || recordingDestination != nil
        isRecording = false
        recordingDestination = nil
        lastTranscription = ""

        audioRecorder.stopRecording()
        speechRecognizer.stopRecognition()
        statusBar.updateRecordingState(false)

        switch destination {
        case .inputPanel:
            recordingInputPanel.cancelRecordingSession()
        case .inject, .none:
            floatingPanel.hideAnimated()
        }

        if shouldShowAlert {
            showAlert(title: "ASR Error", message: message)
        }
    }

    private var currentLanguageCode: String {
        UserDefaults.standard.string(forKey: DefaultsKey.selectedLanguage) ?? "zh-CN"
    }

    private func showRecordingInputPanel() {
        recordingInputPanel.showPanel()
    }

    private func refreshDiagnostics() {
        statusBar.updateAccessibilityStatus(FnKeyMonitor.isAccessibilityGranted())
    }

    private func toggleRecordingInputPanelSession() {
        if isRecording {
            if recordingDestination == .inputPanel {
                stopVoiceInput(for: .inputPanel)
            }
            return
        }

        startVoiceInput(destination: .inputPanel)
    }

    private func handleLanguageChange(_ code: String, persist: Bool = true) {
        if persist {
            UserDefaults.standard.set(code, forKey: DefaultsKey.selectedLanguage)
        }
        speechRecognizer.setLanguage(code)
        statusBar.updateSelectedLanguage(code)
    }
}
