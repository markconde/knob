import Foundation

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
