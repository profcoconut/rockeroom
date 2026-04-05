import Foundation

public struct RouteCandidate: Equatable, Sendable, Codable, Identifiable {
    public var id: String {
        "\(routeContext.destinationID)|\(routeContext.environment.rawValue)|\(routeContext.providerID)|\(routeContext.strategy.persistedLabel)"
    }

    public let routeContext: RouteContext
    public let providerLabel: String

    public init(routeContext: RouteContext, providerLabel: String) {
        self.routeContext = routeContext
        self.providerLabel = providerLabel
    }
}

public struct EvaluatedRouteCandidate: Equatable, Sendable, Codable, Identifiable {
    public var id: String { candidate.id }
    public let candidate: RouteCandidate
    public let score: Double
    public let confidence: Double
    public let freshness: Double
    public let isPartial: Bool
    public let latencyMS: Double?
    public let failureRate: Double?
    public let stabilityScore: Double?
    public let reachabilityScore: Double?
}

public struct RouteCandidateEvaluation: Equatable, Sendable, Codable {
    public let rankedCandidates: [EvaluatedRouteCandidate]
    public let selectedCandidate: EvaluatedRouteCandidate?
    public let degradationReason: String?

    public init(
        rankedCandidates: [EvaluatedRouteCandidate],
        selectedCandidate: EvaluatedRouteCandidate?,
        degradationReason: String? = nil
    ) {
        self.rankedCandidates = rankedCandidates
        self.selectedCandidate = selectedCandidate
        self.degradationReason = degradationReason
    }

    public var isDegraded: Bool {
        degradationReason != nil
    }
}

public protocol RouteCandidateEvaluating: Sendable {
    func evaluate(
        candidates: [RouteCandidate],
        evidence: [ProbeCandidateResult]
    ) -> RouteCandidateEvaluation
}

public struct RouteCandidateEvaluator: RouteCandidateEvaluating {
    public var minimumConfidence: Double
    public var staleFreshnessThreshold: Double
    public var minimumReachability: Double

    public init(
        minimumConfidence: Double = 0.65,
        staleFreshnessThreshold: Double = 0.5,
        minimumReachability: Double = 0.35
    ) {
        self.minimumConfidence = minimumConfidence
        self.staleFreshnessThreshold = staleFreshnessThreshold
        self.minimumReachability = minimumReachability
    }

    public func evaluate(
        candidates: [RouteCandidate],
        evidence: [ProbeCandidateResult]
    ) -> RouteCandidateEvaluation {
        let evidenceByProviderID = Dictionary(uniqueKeysWithValues: evidence.map { ($0.candidateID, $0) })
        let rankedCandidates = candidates.compactMap { candidate -> EvaluatedRouteCandidate? in
            guard supports(candidate.routeContext.strategy),
                  let providerEvidence = evidenceByProviderID[candidate.routeContext.providerID] else {
                return nil
            }

            let reachability = providerEvidence.reachabilityScore ?? (providerEvidence.isPartial ? 0.5 : 1.0)
            let stability = providerEvidence.stabilityScore ?? providerEvidence.score
            let adjustedScore = providerEvidence.score
                + strategyBias(for: candidate.routeContext.strategy)
                + environmentBias(for: candidate.routeContext.environment, strategy: candidate.routeContext.strategy)
                + (reachability * 0.08)
                + ((stability - 0.5) * 0.04)

            return EvaluatedRouteCandidate(
                candidate: candidate,
                score: adjustedScore,
                confidence: providerEvidence.confidence,
                freshness: providerEvidence.freshness,
                isPartial: providerEvidence.isPartial,
                latencyMS: providerEvidence.latencyMS,
                failureRate: providerEvidence.failureRate,
                stabilityScore: stability,
                reachabilityScore: reachability
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.candidate.providerLabel < rhs.candidate.providerLabel
            }
            return lhs.score > rhs.score
        }

        guard let best = rankedCandidates.first else {
            return RouteCandidateEvaluation(
                rankedCandidates: [],
                selectedCandidate: nil,
                degradationReason: "No valid route candidates were available for evaluation."
            )
        }

        let isWeakEvidence = best.confidence < minimumConfidence
            || best.freshness < staleFreshnessThreshold
            || (best.reachabilityScore ?? 0) < minimumReachability
            || best.isPartial

        if isWeakEvidence {
            return RouteCandidateEvaluation(
                rankedCandidates: rankedCandidates,
                selectedCandidate: nil,
                degradationReason: "Route evidence is too weak to claim a healthy best candidate."
            )
        }

        return RouteCandidateEvaluation(
            rankedCandidates: rankedCandidates,
            selectedCandidate: best
        )
    }

    private func supports(_ strategy: RoutingStrategy) -> Bool {
        switch strategy {
        case .rule, .direct, .fallbackProxy:
            return true
        case .custom:
            return false
        }
    }

    private func strategyBias(for strategy: RoutingStrategy) -> Double {
        switch strategy {
        case .rule:
            return 0.03
        case .direct:
            return 0.01
        case .fallbackProxy:
            return 0.02
        case .custom:
            return -0.2
        }
    }

    private func environmentBias(for environment: NetworkEnvironment, strategy: RoutingStrategy) -> Double {
        switch (environment, strategy) {
        case (.cellular, .direct):
            return 0.18
        case (.cellular, .fallbackProxy):
            return -0.08
        case (.wifiHome, .fallbackProxy):
            return 0.12
        case (.wifiHome, .direct):
            return -0.04
        case (.wifiOther, .rule):
            return 0.05
        default:
            return 0
        }
    }
}
