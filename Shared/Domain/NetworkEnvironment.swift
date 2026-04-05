import Foundation

public enum NetworkEnvironment: String, Codable, Equatable, Sendable {
    case unknown
    case wifiHome
    case wifiOther
    case cellular

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
}
