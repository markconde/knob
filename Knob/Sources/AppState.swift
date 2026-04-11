import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.mrkcnd.knob", category: "AppState")

enum AppStatus: Equatable {
    case loading
    case ready
    case recording
    case transcribing
    case error(String)

    var label: String {
        switch self {
        case .loading:      "Loading model..."
        case .ready:        "Ready"
        case .recording:    "Recording..."
        case .transcribing: "Transcribing..."
        case .error(let msg): "Error: \(msg)"
        }
    }

    var icon: String {
        switch self {
        case .recording:    "mic.fill"
        case .transcribing: "mic.badge.ellipsis"
        default:            "mic"
        }
    }
}

@MainActor
@Observable
final class AppState {
    var status: AppStatus = .loading

    private var whisper: WhisperInference?
    private let audioCapture = AudioCapture()
    private let hotkeyListener = HotkeyListener()

    private var chunkPumpTask: Task<Void, Never>?
    private var inflightTranscription: Task<Void, Never>?
    private var pasterSession: TextPaster.Session?

    init() {
        hotkeyListener.onKeyDown = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        hotkeyListener.onKeyUp = { [weak self] in
            DispatchQueue.main.async { self?.stopRecording() }
        }
        audioCapture.onAutoStop = { [weak self] in
            DispatchQueue.main.async { self?.stopRecording() }
        }

        Task { [weak self] in
            await self?.loadModel()
        }
    }

    private func loadModel() async {
        logger.info("Loading whisper model...")
        do {
            whisper = try await Task.detached {
                try WhisperInference.load()
            }.value
            logger.info("Model loaded successfully.")
            status = .ready
            hotkeyListener.start()
        } catch WhisperError.modelNotFound(let path) {
            logger.error("Model not found at \(path)")
            status = .error("Model not found")
        } catch {
            logger.error("Failed to load model: \(error.localizedDescription)")
            status = .error("Failed to load model")
        }
    }

    private func startRecording() {
        guard status == .ready else {
            logger.warning("startRecording called but status is \(self.status.label)")
            return
        }
        logger.info("Recording started.")
        status = .recording
        audioCapture.startRecording()
        pasterSession = TextPaster.beginSession()

        chunkPumpTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                self?.pumpOnce()
            }
        }
    }

    /// Tries to drain a silence-bounded chunk from the live recording and
    /// hand it off to whisper. Transcription tasks are chained so paste order
    /// always matches capture order.
    private func pumpOnce() {
        guard status == .recording else { return }
        guard let chunk = audioCapture.tryDrainChunk() else { return }
        guard let whisper, let session = pasterSession else { return }

        logger.info("Chunk drained (\(String(format: "%.1f", Double(chunk.count) / 16000.0))s), queueing transcription.")

        let previous = inflightTranscription
        inflightTranscription = Task {
            await previous?.value
            do {
                let text = try await whisper.transcribe(samples: chunk)
                logger.info("Chunk transcription: \(text)")
                if !text.isEmpty {
                    await MainActor.run { session.paste(text) }
                }
            } catch {
                logger.error("Chunk transcription failed: \(error.localizedDescription)")
            }
        }
    }

    private func stopRecording() {
        guard status == .recording else { return }
        logger.info("Recording stopped. Finalizing...")
        status = .transcribing

        chunkPumpTask?.cancel()
        chunkPumpTask = nil

        let tailSamples = audioCapture.stopRecording()

        guard let whisper else {
            status = .error("Model not loaded")
            pasterSession = nil
            inflightTranscription = nil
            return
        }

        let previous = inflightTranscription
        let session = pasterSession

        Task {
            await previous?.value

            if let samples = tailSamples {
                logger.info("Transcribing tail \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s)...")
                do {
                    let text = try await whisper.transcribe(samples: samples)
                    logger.info("Tail transcription: \(text)")
                    if !text.isEmpty {
                        await MainActor.run { session?.paste(text) }
                    }
                } catch {
                    logger.error("Tail transcription failed: \(error.localizedDescription)")
                }
            } else {
                logger.info("No tail samples (too short). Skipping final transcription.")
            }

            await MainActor.run {
                session?.finish()
                self.pasterSession = nil
                self.inflightTranscription = nil
                self.status = .ready
            }
        }
    }
}
