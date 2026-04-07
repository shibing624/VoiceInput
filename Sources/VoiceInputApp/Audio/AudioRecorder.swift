import AVFoundation

final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var isRecording = false

    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onRMSLevel: ((Float) -> Void)?

    func startRecording() throws {
        guard !isRecording else { return }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        onAudioBuffer?(buffer)

        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        let samples = channelData[0]
        var sumOfSquares: Float = 0
        for i in 0..<frames {
            let sample = samples[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrtf(sumOfSquares / Float(frames))

        DispatchQueue.main.async { [weak self] in
            self?.onRMSLevel?(rms)
        }
    }
}
