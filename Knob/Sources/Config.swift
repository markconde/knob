import Foundation
import os

private let logger = Logger(subsystem: "com.mrkcnd.knob", category: "Config")

struct Config: Codable {
    var model: String
    var language: String

    static let defaultConfig = Config(
        model: "ggml-small.en.bin",
        language: "en"
    )

    static let directoryURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Knob")
    }()

    static let fileURL: URL = directoryURL.appendingPathComponent("config.json")
    static let modelsURL: URL = directoryURL.appendingPathComponent("models")

    var modelPath: String {
        Self.modelsURL.appendingPathComponent(model).path
    }

    /// Loads config from ~/Library/Application Support/Knob/config.json.
    /// Creates the file with defaults if it doesn't exist.
    static func load() -> Config {
        let url = fileURL

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let config = try JSONDecoder().decode(Config.self, from: data)
                logger.info("Config loaded: model=\(config.model), language=\(config.language)")
                return config
            } catch {
                logger.error("Failed to read config.json, using defaults: \(error.localizedDescription)")
                return defaultConfig
            }
        }

        // First run — write defaults so the user has a file to edit
        let config = defaultConfig
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: url)
            logger.info("Created default config.json")
        } catch {
            logger.warning("Could not write default config.json: \(error.localizedDescription)")
        }
        return config
    }
}
