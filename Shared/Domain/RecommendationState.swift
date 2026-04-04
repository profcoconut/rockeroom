import Foundation

public enum RecommendationState: Equatable, Sendable {
    case idle
    case evaluating
    case recommended(RecommendationSummary)
    case holding(RecommendationHold)
    case rejected(RecommendationRejection)
}

public struct RecommendationSummary: Equatable, Sendable {
    public var selectedCandidateID: String
    public var proof: ProofPayload
    public var confidence: Double
    public var freshness: Double

    public init(
        selectedCandidateID: String,
        proof: ProofPayload,
        confidence: Double,
        freshness: Double
    ) {
        self.selectedCandidateID = selectedCandidateID
        self.proof = proof
        self.confidence = confidence
        self.freshness = freshness
    }
}

public struct RecommendationHold: Equatable, Sendable {
    public var reason: RecommendationHoldReason
    public var proof: ProofPayload?
    public var confidence: Double
    public var freshness: Double

    public init(
        reason: RecommendationHoldReason,
        proof: ProofPayload?,
        confidence: Double,
        freshness: Double
    ) {
        self.reason = reason
        self.proof = proof
        self.confidence = confidence
        self.freshness = freshness
    }
}

public struct RecommendationRejection: Equatable, Sendable {
    public var reason: RecommendationRejectionReason
    public var message: String

    public init(reason: RecommendationRejectionReason, message: String) {
        self.reason = reason
        self.message = message
    }
}

public enum RecommendationHoldReason: String, Equatable, Sendable {
    case pinned
    case lowConfidence
    case insignificantDelta
    case staleData
    case noCandidates
}

public enum RecommendationRejectionReason: String, Equatable, Sendable {
    case noCandidates
    case invalidSnapshot
}

public enum PinState: Equatable, Sendable, Codable {
    case none
    case pinned(candidateID: String)

    public var candidateID: String? {
        switch self {
        case .none:
            return nil
        case .pinned(let candidateID):
            return candidateID
        }
    }
}
