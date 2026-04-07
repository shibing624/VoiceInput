import AppKit

final class FloatingPanel: NSPanel {
    private let waveformView = WaveformView(frame: NSRect(x: 0, y: 0, width: 36, height: 24))
    private let textLabel = NSTextField(labelWithString: "")
    private let backgroundView = NSView()
    private var widthConstraint: NSLayoutConstraint!
    private let minWidth: CGFloat = 120
    private let maxWidth: CGFloat = 480
    private let panelHeight: CGFloat = 40

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 40),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isMovableByWindowBackground = false
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupViews()
        positionAtScreenBottom()
    }

    private func setupViews() {
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = panelHeight / 2
        backgroundView.layer?.masksToBounds = true
        // Warm white background with subtle border
        backgroundView.layer?.backgroundColor = NSColor(white: 0.98, alpha: 0.96).cgColor
        backgroundView.layer?.borderColor = NSColor(white: 0.0, alpha: 0.08).cgColor
        backgroundView.layer?.borderWidth = 0.5
        // Soft shadow via the panel
        backgroundView.shadow = NSShadow()
        backgroundView.layer?.shadowColor = NSColor(white: 0.0, alpha: 0.15).cgColor
        backgroundView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        backgroundView.layer?.shadowRadius = 12
        backgroundView.layer?.shadowOpacity = 1.0
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView(frame: .zero)
        self.contentView = contentView
        contentView.addSubview(backgroundView)

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(waveformView)

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.maximumNumberOfLines = 1
        textLabel.isEditable = false
        textLabel.isBezeled = false
        textLabel.drawsBackground = false
        textLabel.isSelectable = false
        textLabel.cell?.truncatesLastVisibleLine = true
        backgroundView.addSubview(textLabel)

        widthConstraint = backgroundView.widthAnchor.constraint(equalToConstant: minWidth)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            backgroundView.heightAnchor.constraint(equalToConstant: panelHeight),
            widthConstraint,

            waveformView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 14),
            waveformView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 36),
            waveformView.heightAnchor.constraint(equalToConstant: 24),

            textLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(lessThanOrEqualTo: backgroundView.trailingAnchor, constant: -14),
            textLabel.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
        ])
    }

    private func positionAtScreenBottom() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - minWidth / 2
        let y = screenFrame.minY + 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func updateRMS(_ rms: Float) {
        waveformView.updateRMS(rms)
    }

    func updateText(_ text: String) {
        textLabel.stringValue = text

        let textWidth = textLabel.attributedStringValue.size().width
        let totalWidth = 14 + 36 + 8 + textWidth + 14
        let newWidth = min(max(totalWidth, minWidth), maxWidth)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            widthConstraint.animator().constant = newWidth

            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - newWidth / 2
            let y = screenFrame.minY + 80
            self.animator().setFrameOrigin(NSPoint(x: x, y: y))
            self.animator().setContentSize(NSSize(width: newWidth, height: panelHeight))
        }
    }

    func showAnimated() {
        alphaValue = 0
        setFrame(frame, display: false)

        contentView?.wantsLayer = true
        contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.85, y: 0.85))

        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            self.animator().alphaValue = 1
            self.contentView?.layer?.setAffineTransform(.identity)
        }
    }

    func hideAnimated(completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            self.animator().alphaValue = 0
            self.contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.85, y: 0.85))
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
            self?.waveformView.reset()
            self?.textLabel.stringValue = ""
            self?.widthConstraint.constant = self?.minWidth ?? 120
            self?.contentView?.layer?.setAffineTransform(.identity)
            completion?()
        })
    }
}
