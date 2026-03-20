import AVFoundation
import Foundation
import os

private let logger = Logger(subsystem: "com.mrkcnd.knob", category: "AudioCapture")

@MainActor
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var sharedBuffer: SharedBuffer?
    private var autoStopTask: Task<Void, Never>?

    var onAutoStop: (@Sendable () -> Void)?

    func startRecording() {
        let buf = SharedBuffer()
        sharedBuffer = buf

        let inputNode = engine.inputNode
        let hwFormat = inputNode.inputFormat(forBus: 0)
        let hwSampleRate = hwFormat.sampleRate
        logger.info("Hardware format: \(hwSampleRate)Hz, \(hwFormat.channelCount)ch")

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { @Sendable pcmBuffer, _ in
            guard let channelData = pcmBuffer.floatChannelData?[0] else { return }
            let frameCount = Int(pcmBuffer.frameLength)

            // Resample to 16kHz
            let samples: [Float]
            if abs(hwSampleRate - 16000.0) < 1.0 {
                // Already 16kHz
                samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
            } else {
                // Linear interpolation resample
                let ratio = hwSampleRate / 16000.0
                let outputCount = Int(Double(frameCount) / ratio)
                var resampled = [Float](repeating: 0, count: outputCount)
                for i in 0..<outputCount {
                    let srcIdx = Double(i) * ratio
                    let idx0 = Int(srcIdx)
                    let frac = Float(srcIdx - Double(idx0))
                    let idx1 = min(idx0 + 1, frameCount - 1)
                    resampled[i] = channelData[idx0] * (1.0 - frac) + channelData[idx1] * frac
                }
                samples = resampled
            }
            buf.append(samples)
        }

        do {
            try engine.start()
            logger.info("Audio engine started.")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            return
        }

        autoStopTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.onAutoStop?()
        }
    }

    func stopRecording() -> [Float]? {
        autoStopTask?.cancel()
        autoStopTask = nil

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        guard let buf = sharedBuffer else { return nil }
        let samples = buf.drain()
        sharedBuffer = nil

        let duration = Double(samples.count) / 16000.0
        logger.info("Recorded \(String(format: "%.2f", duration))s (\(samples.count) samples)")

        guard duration >= 0.5 else {
            logger.info("Too short, discarding.")
            return nil
        }

        return samples
    }
}

private final class SharedBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []

    func append(_ newSamples: [Float]) {
        lock.lock()
        samples.append(contentsOf: newSamples)
        lock.unlock()
    }

    func drain() -> [Float] {
        lock.lock()
        let result = samples
        samples = []
        lock.unlock()
        return result
    }
}
