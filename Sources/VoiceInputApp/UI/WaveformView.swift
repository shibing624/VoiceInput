import AppKit

final class WaveformView: NSView {
    private let barCount = 5
    private let barWeights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private var smoothedLevels: [Float]
    private var displayLink: CVDisplayLink?
    private var currentRMS: Float = 0
    private let attackCoeff: Float = 0.4
    private let releaseCoeff: Float = 0.15

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2.5
    private let minBarHeight: CGFloat = 3
    private let maxBarHeight: CGFloat = 22

    // Warm accent color for waveform bars (coral-orange)
    private let barColor = NSColor(red: 0.95, green: 0.45, blue: 0.30, alpha: 1.0)

    override init(frame: NSRect) {
        smoothedLevels = Array(repeating: 0, count: barCount)
        super.init(frame: frame)
        wantsLayer = true
        startDisplayLink()
    }

    required init?(coder: NSCoder) {
        smoothedLevels = Array(repeating: 0, count: barCount)
        super.init(coder: coder)
        wantsLayer = true
        startDisplayLink()
    }

    deinit {
        stopDisplayLink()
    }

    func updateRMS(_ rms: Float) {
        currentRMS = rms
    }

    func reset() {
        currentRMS = 0
        for i in 0..<barCount {
            smoothedLevels[i] = 0
        }
        needsDisplay = true
    }

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        displayLink = link

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo -> CVReturn in
            let view = Unmanaged<WaveformView>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                view.tick()
            }
            return kCVReturnSuccess
        }

        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
            displayLink = nil
        }
    }

    private func tick() {
        let rms = currentRMS
        for i in 0..<barCount {
            let target = rms * barWeights[i] + Float.random(in: -0.03...0.03)
            let coeff = target > smoothedLevels[i] ? attackCoeff : releaseCoeff
            smoothedLevels[i] += coeff * (target - smoothedLevels[i])
            smoothedLevels[i] = max(0, smoothedLevels[i])
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2

        for i in 0..<barCount {
            let normalized = min(smoothedLevels[i] * 5.0, 1.0)
            let barHeight = minBarHeight + CGFloat(normalized) * (maxBarHeight - minBarHeight)
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let y = centerY - barHeight / 2
            let rect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = CGPath(roundedRect: rect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil)

            // Opacity varies slightly per bar for depth
            let alpha = 0.7 + 0.3 * CGFloat(normalized)
            ctx.setFillColor(barColor.withAlphaComponent(alpha).cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 36, height: 24)
    }
}
