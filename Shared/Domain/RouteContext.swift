import Foundation

public struct RouteContext: Codable, Equatable, Sendable {
    public let environment: NetworkEnvironment
    public let destinationID: String
    public let providerID: String
    public let strategy: RoutingStrategy

    public init(
        environment: NetworkEnvironment = .unknown,
        destinationID: String,
        providerID: String,
        strategy: RoutingStrategy
    ) {
        self.environment = environment
        self.destinationID = destinationID
        self.providerID = providerID
        self.strategy = strategy
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        environment = try container.decodeIfPresent(NetworkEnvironment.self, forKey: .environment) ?? .unknown
        destinationID = try container.decode(String.self, forKey: .destinationID)
        providerID = try container.decode(String.self, forKey: .providerID)
        strategy = try container.decode(RoutingStrategy.self, forKey: .strategy)
    }

    private enum CodingKeys: String, CodingKey {
        case environment
        case destinationID
        case providerID
        case strategy
    }
}
