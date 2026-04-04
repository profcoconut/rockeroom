import Foundation

public struct EvidenceProjection: Equatable, Sendable {
    public var primaryState: EvidenceProjectionState
    public var headline: String
    public var summaryText: String
    public var stateBadges: [EvidenceBadge]
    public var cards: [EvidenceCard]
    public var featuredProof: ProofPayload?
    public var emptyMessage: String?

    public init(
        primaryState: EvidenceProjectionState,
        headline: String,
        summaryText: String,
        stateBadges: [EvidenceBadge],
        cards: [EvidenceCard],
        featuredProof: ProofPayload?,
        emptyMessage: String? = nil
    ) {
        self.primaryState = primaryState
        self.headline = headline
        self.summaryText = summaryText
        self.stateBadges = stateBadges
        self.cards = cards
        self.featuredProof = featuredProof
        self.emptyMessage = emptyMessage
    }

    public static func project(
        snapshot: ResultSnapshot?,
        recommendationState: RecommendationState,
        pinState: PinState,
        policy: RecommendationPolicy = RecommendationPolicy()
    ) -> EvidenceProjection {
        guard let snapshot, !snapshot.candidates.isEmpty else {
            return EvidenceProjection(
                primaryState: .empty,
                headline: "Marketplace",
                summaryText: "No marketplace evidence yet.",
                stateBadges: [],
                cards: [],
                featuredProof: nil,
                emptyMessage: "Run Optimize to collect marketplace evidence."
            )
        }

        let orderedCandidates = snapshot.candidates.sorted(by: { $0.score > $1.score })
        guard let bestCandidate = orderedCandidates.first else {
            return degradedProjection(
                headline: "Marketplace",
                summaryText: "Marketplace evidence could not be evaluated.",
                cards: [],
                featuredProof: nil
            )
        }
        let runnerUpCandidate = orderedCandidates.dropFirst().first

        let evaluation = canonicalRecommendationState(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: pinState,
            policy: policy
        )

        let resolution = resolveActiveCandidateID(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: pinState,
            fallbackCandidateID: bestCandidate.candidateID
        )

        let projectionState = primaryState(
            snapshot: snapshot,
            isDegraded: resolution.isDegraded
        )
        let stateBadges = badges(
            for: snapshot,
            isDegraded: resolution.isDegraded
        )
        let featuredProof = proofPayload(
            from: evaluation,
            snapshot: snapshot,
            policy: policy,
            bestCandidate: bestCandidate,
            runnerUpCandidate: runnerUpCandidate
        )

        let cards = orderedCandidates.enumerated().map { index, candidate in
            EvidenceCard(
                candidateID: candidate.candidateID,
                label: candidate.label,
                rank: index + 1,
                score: candidate.score,
                scoreText: String(format: "Score %.0f%%", candidate.score * 100),
                metrics: candidate.metrics,
                markers: markers(
                    candidateID: candidate.candidateID,
                    activeCandidateID: resolution.activeCandidateID,
                    recommendationState: evaluation,
                    pinState: pinState
                ),
                stateBadges: stateBadges,
                proof: candidate.candidateID == resolution.activeCandidateID ? featuredProof : nil,
                summaryText: summaryText(
                    for: candidate.candidateID,
                    activeCandidateID: resolution.activeCandidateID,
                    pinState: pinState,
                    recommendationState: evaluation
                )
            )
        }

        return EvidenceProjection(
            primaryState: projectionState,
            headline: "Marketplace",
            summaryText: summaryText(for: projectionState, badges: stateBadges),
            stateBadges: stateBadges,
            cards: cards,
            featuredProof: featuredProof,
            emptyMessage: nil
        )
    }

    private static func degradedProjection(
        headline: String,
        summaryText: String,
        cards: [EvidenceCard],
        featuredProof: ProofPayload?
    ) -> EvidenceProjection {
        EvidenceProjection(
            primaryState: .degraded,
            headline: headline,
            summaryText: summaryText,
            stateBadges: [.degraded],
            cards: cards,
            featuredProof: featuredProof,
            emptyMessage: nil
        )
    }

    private static func canonicalRecommendationState(
        snapshot: ResultSnapshot,
        recommendationState: RecommendationState,
        pinState: PinState,
        policy: RecommendationPolicy
    ) -> RecommendationState {
        switch recommendationState {
        case .idle, .evaluating:
            return policy.evaluate(snapshot: snapshot, pinState: pinState)
        case .recommended, .holding, .rejected:
            return recommendationState
        }
    }

    private static func resolveActiveCandidateID(
        snapshot: ResultSnapshot,
        recommendationState: RecommendationState,
        pinState: PinState,
        fallbackCandidateID: String
    ) -> (activeCandidateID: String, isDegraded: Bool) {
        let candidateIDs = Set(snapshot.candidates.map(\.candidateID))

        if let pinnedID = pinState.candidateID {
            if candidateIDs.contains(pinnedID) {
                return (pinnedID, false)
            }
            return (fallbackCandidateID, true)
        }

        if let selectedCandidateID = recommendationState.selectedCandidateID {
            if candidateIDs.contains(selectedCandidateID) {
                return (selectedCandidateID, false)
            }
            return (fallbackCandidateID, true)
        }

        if let selectedCandidateID = snapshot.selectedCandidateID {
            if candidateIDs.contains(selectedCandidateID) {
                return (selectedCandidateID, false)
            }
            return (fallbackCandidateID, true)
        }

        return (fallbackCandidateID, false)
    }

    private static func primaryState(snapshot: ResultSnapshot, isDegraded: Bool) -> EvidenceProjectionState {
        if isDegraded {
            return .degraded
        }
        if snapshot.isPartial {
            return .partial
        }
        if snapshot.freshness < 0.5 {
            return .stale
        }
        return .current
    }

    private static func badges(for snapshot: ResultSnapshot, isDegraded: Bool) -> [EvidenceBadge] {
        var badges: [EvidenceBadge] = []
        if snapshot.freshness < 0.5 {
            badges.append(.stale)
        }
        if snapshot.isPartial {
            badges.append(.partial)
        }
        if isDegraded {
            badges.append(.degraded)
        }
        return badges
    }

    private static func proofPayload(
        from recommendationState: RecommendationState,
        snapshot: ResultSnapshot,
        policy: RecommendationPolicy,
        bestCandidate: ProbeCandidateResult,
        runnerUpCandidate: ProbeCandidateResult?
    ) -> ProofPayload? {
        switch recommendationState {
        case .recommended(let summary):
            return summary.proof
        case .holding(let hold):
            return hold.proof ?? policy.makeProof(best: bestCandidate, runnerUp: runnerUpCandidate, snapshot: snapshot)
        case .rejected, .idle, .evaluating:
            return policy.makeProof(best: bestCandidate, runnerUp: runnerUpCandidate, snapshot: snapshot)
        }
    }

    private static func markers(
        candidateID: String,
        activeCandidateID: String,
        recommendationState: RecommendationState,
        pinState: PinState
    ) -> [EvidenceCardMarker] {
        var markers: [EvidenceCardMarker] = []

        if candidateID == activeCandidateID {
            markers.append(.current)
        }

        if case .recommended(let summary) = recommendationState, summary.selectedCandidateID == candidateID {
            markers.append(.recommended)
        }

        if pinState.candidateID == candidateID {
            markers.append(.pinned)
        }

        return markers
    }

    private static func summaryText(
        for candidateID: String,
        activeCandidateID: String,
        pinState: PinState,
        recommendationState: RecommendationState
    ) -> String {
        if candidateID == activeCandidateID {
            if pinState.candidateID == candidateID {
                return "Pinned by the user."
            }

            if case .recommended(let summary) = recommendationState, summary.selectedCandidateID == candidateID {
                return "Recommended by the shared policy."
            }

            return "Current active setup."
        }

        return "Alternative evidence card."
    }

    private static func summaryText(for state: EvidenceProjectionState, badges: [EvidenceBadge]) -> String {
        switch state {
        case .empty:
            return "No marketplace evidence yet."
        case .current:
            return "Marketplace evidence is current."
        case .stale:
            return "Marketplace evidence is stale. Refresh to update it."
        case .partial:
            if badges.contains(.stale) {
                return "Marketplace evidence is partial and stale."
            }
            return "Marketplace evidence is partial."
        case .degraded:
            return "Marketplace evidence is degraded. Refresh to recover it."
        }
    }
}

public enum EvidenceProjectionState: String, Equatable, Sendable {
    case empty
    case current
    case stale
    case partial
    case degraded
}

public enum EvidenceBadge: String, Equatable, Sendable {
    case stale
    case partial
    case degraded
}

public enum EvidenceCardMarker: String, Equatable, Sendable {
    case current
    case recommended
    case pinned
}

public struct EvidenceCard: Equatable, Sendable, Identifiable {
    public var id: String { candidateID }
    public var candidateID: String
    public var label: String
    public var rank: Int
    public var score: Double
    public var scoreText: String
    public var metrics: [ProbeMetric]
    public var markers: [EvidenceCardMarker]
    public var stateBadges: [EvidenceBadge]
    public var proof: ProofPayload?
    public var summaryText: String

    public init(
        candidateID: String,
        label: String,
        rank: Int,
        score: Double,
        scoreText: String,
        metrics: [ProbeMetric],
        markers: [EvidenceCardMarker],
        stateBadges: [EvidenceBadge],
        proof: ProofPayload?,
        summaryText: String
    ) {
        self.candidateID = candidateID
        self.label = label
        self.rank = rank
        self.score = score
        self.scoreText = scoreText
        self.metrics = metrics
        self.markers = markers
        self.stateBadges = stateBadges
        self.proof = proof
        self.summaryText = summaryText
    }
}

private extension RecommendationState {
    var selectedCandidateID: String? {
        switch self {
        case .recommended(let summary):
            return summary.selectedCandidateID
        case .holding, .rejected, .idle, .evaluating:
            return nil
        }
    }
}
