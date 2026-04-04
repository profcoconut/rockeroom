import Foundation

public enum SubscriptionImportResult: Equatable, Sendable {
    case accepted(SubscriptionConfig)
    case rejected(SubscriptionImportFailure)
}

public struct SubscriptionImportFailure: Error, Equatable, Sendable {
    public var reason: SubscriptionImportFailureReason
    public var message: String
    public var isRetryable: Bool

    public init(
        reason: SubscriptionImportFailureReason,
        message: String,
        isRetryable: Bool = false
    ) {
        self.reason = reason
        self.message = message
        self.isRetryable = isRetryable
    }
}

public enum SubscriptionImportFailureReason: String, Equatable, Sendable {
    case invalidURL
    case fetchFailed
    case emptyContent
    case malformedContent
    case unsupportedContent
}
