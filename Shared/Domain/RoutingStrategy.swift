import Foundation

public enum RoutingStrategy: Equatable, Sendable, Codable {
    case rule
    case direct
    case fallbackProxy
    case custom(String)

    public var stableID: String {
        switch self {
        case .rule:
            return "rule"
        case .direct:
            return "direct"
        case .fallbackProxy:
            return "fallback-proxy"
        case .custom:
            return "custom"
        }
    }

    public var persistedLabel: String {
        switch self {
        case .rule:
            return "rule"
        case .direct:
            return "direct"
        case .fallbackProxy:
            return "fallback-proxy"
        case .custom(let label):
            return label
        }
    }

    public init(legacyName: String) {
        switch legacyName {
        case "rule":
            self = .rule
        case "direct":
            self = .direct
        case "fallback-proxy":
            self = .fallbackProxy
        default:
            self = .custom(legacyName)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = RoutingStrategy(legacyName: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(persistedLabel)
    }
}
