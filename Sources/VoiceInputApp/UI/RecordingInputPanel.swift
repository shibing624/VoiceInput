import AppKit

final class RecordingInputPanel: NSPanel, NSWindowDelegate {
    var onToggleRecording: (() -> Void)?

    private let textView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let recordButton = NSButton(title: "Start Recording", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)

    private var committedText = ""
    private var draftText = ""
    private var isRecordingSession = false

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = "Recording Input Box"
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces]
        delegate = self
        setupUI()
    }

    func showPanel() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func beginRecordingSession() {
        committedText = textView.string
        draftText = ""
        isRecordingSession = true
        textView.isEditable = false
        updateRecordingButton()
        setStatus("Recording...")
        renderText()
        showPanel()
    }

    func updateDraftText(_ text: String) {
        draftText = text
        renderText()
    }

    func finishRecordingSession(with text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            if !committedText.isEmpty && !committedText.hasSuffix("\n") {
                committedText += "\n"
            }
            committedText += cleaned
        }

        draftText = ""
        isRecordingSession = false
        textView.isEditable = true
        updateRecordingButton()
        setStatus("Ready")
        renderText()
        showPanel()
    }

    func cancelRecordingSession() {
        draftText = ""
        isRecordingSession = false
        textView.isEditable = true
        updateRecordingButton()
        setStatus("Ready")
        renderText()
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func windowWillClose(_ notification: Notification) {
        if isRecordingSession {
            onToggleRecording?()
        }
    }

    private func setupUI() {
        center()

        let container = NSView(frame: contentRect(forFrameRect: frame))
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView = container

        let headerLabel = NSTextField(labelWithString: "Collect ASR text here when no app input box is focused.")
        headerLabel.font = NSFont.systemFont(ofSize: 13)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        recordButton.target = self
        recordButton.action = #selector(toggleRecording(_:))
        recordButton.bezelStyle = .rounded
        recordButton.translatesAutoresizingMaskIntoConstraints = false

        copyButton.target = self
        copyButton.action = #selector(copyText(_:))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false

        clearButton.target = self
        clearButton.action = #selector(clearText(_:))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scrollView.documentView = textView

        container.addSubview(headerLabel)
        container.addSubview(statusLabel)
        container.addSubview(recordButton)
        container.addSubview(copyButton)
        container.addSubview(clearButton)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),

            clearButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            copyButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),

            recordButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            recordButton.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])
    }

    private func updateRecordingButton() {
        recordButton.title = isRecordingSession ? "Stop Recording" : "Start Recording"
    }

    private func renderText() {
        var rendered = committedText
        if !draftText.isEmpty {
            if !rendered.isEmpty && !rendered.hasSuffix("\n") {
                rendered += "\n"
            }
            rendered += draftText
        }

        textView.string = rendered
        textView.scrollToEndOfDocument(nil)
    }

    @objc private func toggleRecording(_ sender: NSButton) {
        onToggleRecording?()
    }

    @objc private func copyText(_ sender: NSButton) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        setStatus("Copied")
    }

    @objc private func clearText(_ sender: NSButton) {
        guard !isRecordingSession else { return }
        committedText = ""
        draftText = ""
        textView.string = ""
        setStatus("Cleared")
    }
}
