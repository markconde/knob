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
    }

    private func stopRecording() {
        guard status == .recording else { return }
        logger.info("Recording stopped. Getting samples...")
        status = .transcribing

        guard let samples = audioCapture.stopRecording() else {
            logger.info("No samples (too short). Returning to ready.")
            status = .ready
            return
        }

        guard let whisper else {
            status = .error("Model not loaded")
            return
        }

        logger.info("Transcribing \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s)...")

        Task {
            do {
                let text = try await whisper.transcribe(samples: samples)
                logger.info("Transcription result: \(text)")
                if !text.isEmpty {
                    TextPaster.paste(text)
                }
            } catch {
                logger.error("Transcription failed: \(error.localizedDescription)")
            }
            status = .ready
        }
    }
}
