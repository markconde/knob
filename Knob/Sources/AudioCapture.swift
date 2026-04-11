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

    /// Attempts to drain a silence-bounded chunk from the live buffer without
    /// stopping recording. Returns nil if fewer than `minSamples` have been
    /// captured or no silence has been detected yet.
    func tryDrainChunk(minSamples: Int = 80_000) -> [Float]? {
        guard let buf = sharedBuffer else { return nil }
        guard buf.count >= minSamples else { return nil }
        // Start looking for silence a bit before the minimum so the split
        // point can land near `minSamples` if a pause happens right there.
        let windowSamples = 4800
        let scanStart = max(0, minSamples - windowSamples)
        return buf.findAndDrainSilenceSplit(
            minIndex: scanStart,
            windowSamples: windowSamples
        )
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

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return samples.count
    }

    /// Finds the first sustained silence window starting at or after `minIndex`
    /// and drains the buffer up to the middle of that window. Returns the
    /// drained prefix, or nil if no silence window exists.
    ///
    /// Silence = a window of `windowSamples` consecutive samples whose RMS is
    /// below `rmsThreshold`. Splitting at the middle of the silence keeps
    /// safety margin on both sides so we never cut mid-word.
    func findAndDrainSilenceSplit(
        minIndex: Int,
        windowSamples: Int = 4800,
        rmsThreshold: Float = 0.01
    ) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }

        let start = max(0, minIndex)
        guard samples.count >= start + windowSamples else { return nil }

        let thresholdSq = rmsThreshold * rmsThreshold * Float(windowSamples)

        // Sliding sum-of-squares over the window. Initialize with the first
        // window's sum, then slide one sample at a time.
        var sumSq: Float = 0
        for i in start..<(start + windowSamples) {
            let s = samples[i]
            sumSq += s * s
        }

        var windowStart = start
        let lastStart = samples.count - windowSamples
        while windowStart <= lastStart {
            if sumSq < thresholdSq {
                // Split at the middle of the silent window.
                let splitIndex = windowStart + windowSamples / 2
                let prefix = Array(samples[0..<splitIndex])
                samples.removeFirst(splitIndex)
                return prefix
            }
            // Slide: subtract outgoing sample, add incoming sample.
            let next = windowStart + windowSamples
            if next >= samples.count { break }
            let out = samples[windowStart]
            let inc = samples[next]
            sumSq += inc * inc - out * out
            windowStart += 1
        }

        return nil
    }
}
