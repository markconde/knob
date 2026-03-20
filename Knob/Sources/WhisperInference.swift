import Foundation

enum WhisperError: Error {
    case modelNotFound(String)
    case failedToInitialize
    case transcriptionFailed
}

actor WhisperInference {
    private nonisolated(unsafe) let context: OpaquePointer

    private init(context: OpaquePointer) {
        self.context = context
    }

    deinit {
        whisper_free(context)
    }

    static func load() throws -> WhisperInference {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelPath = appSupport.appendingPathComponent("Knob/models/ggml-small.en.bin").path

        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw WhisperError.modelNotFound(modelPath)
        }

        var params = whisper_context_default_params()
        params.flash_attn = true

        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw WhisperError.failedToInitialize
        }

        return WhisperInference(context: ctx)
    }

    private static func loadVocab() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let vocabPath = appSupport.appendingPathComponent("Knob/vocab.txt").path
        guard let contents = try? String(contentsOfFile: vocabPath, encoding: .utf8) else {
            return nil
        }
        let words = contents.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return words.isEmpty ? nil : words.joined(separator: ", ")
    }

    func transcribe(samples: [Float]) throws -> String {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        let vocab = Self.loadVocab()

        let result: Int32 = "en".withCString { lang in
            params.n_threads        = 4
            params.no_context       = true
            params.single_segment   = true
            params.suppress_blank   = true
            params.suppress_nst     = true
            params.translate        = false
            params.language         = lang
            params.print_realtime   = false
            params.print_progress   = false
            params.print_timestamps = false

            if let vocab {
                return vocab.withCString { prompt in
                    params.initial_prompt = prompt
                    return samples.withUnsafeBufferPointer { buf in
                        whisper_full(context, params, buf.baseAddress, Int32(samples.count))
                    }
                }
            } else {
                return samples.withUnsafeBufferPointer { buf in
                    whisper_full(context, params, buf.baseAddress, Int32(samples.count))
                }
            }
        }

        guard result == 0 else {
            throw WhisperError.transcriptionFailed
        }

        var transcription = ""
        let nSegments = whisper_full_n_segments(context)
        for i in 0..<nSegments {
            transcription += String(cString: whisper_full_get_segment_text(context, i))
        }

        // Post-processing: trim whitespace and leading space
        return transcription.trimmingCharacters(in: .whitespaces)
    }
}
