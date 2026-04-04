import Foundation

public struct StoredSubscription: Codable, Equatable, Sendable {
    public var subscriptionLink: String
    public var config: SubscriptionConfig

    public init(subscriptionLink: String, config: SubscriptionConfig) {
        self.subscriptionLink = subscriptionLink
        self.config = config
    }
}
