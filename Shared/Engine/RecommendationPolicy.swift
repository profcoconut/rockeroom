import Foundation

public struct RecommendationPolicy {
    public var minimumConfidence: Double
    public var minimumScoreDelta: Double
    public var staleFreshnessThreshold: Double

    public init(
        minimumConfidence: Double = 0.65,
        minimumScoreDelta: Double = 0.12,
        staleFreshnessThreshold: Double = 0.5
    ) {
        self.minimumConfidence = minimumConfidence
        self.minimumScoreDelta = minimumScoreDelta
        self.staleFreshnessThreshold = staleFreshnessThreshold
    }

    public func evaluate(
        snapshot: ResultSnapshot,
        pinState: PinState
    ) -> RecommendationState {
        guard !snapshot.candidates.isEmpty else {
            return .rejected(
                RecommendationRejection(
                    reason: .noCandidates,
                    message: "No candidates were available for recommendation."
                )
            )
        }

        let ordered = snapshot.candidates.sorted(by: { $0.score > $1.score })
        guard let best = ordered.first else {
            return .rejected(
                RecommendationRejection(
                    reason: .invalidSnapshot,
                    message: "The snapshot could not be evaluated."
                )
            )
        }
        let runnerUp = ordered.dropFirst().first
        let proof = makeProof(best: best, runnerUp: runnerUp, snapshot: snapshot)

        if snapshot.freshness < staleFreshnessThreshold {
            return .holding(
                RecommendationHold(
                    reason: .staleData,
                    proof: proof,
                    confidence: snapshot.overallConfidence,
                    freshness: snapshot.freshness
                )
            )
        }

        if let pinnedID = pinState.candidateID, pinnedID != best.candidateID {
            return .holding(
                RecommendationHold(
                    reason: .pinned,
                    proof: proof,
                    confidence: snapshot.overallConfidence,
                    freshness: snapshot.freshness
                )
            )
        }

        guard snapshot.overallConfidence >= minimumConfidence else {
            return .holding(
                RecommendationHold(
                    reason: .lowConfidence,
                    proof: proof,
                    confidence: snapshot.overallConfidence,
                    freshness: snapshot.freshness
                )
            )
        }

        if let runnerUp, (best.score - runnerUp.score) < minimumScoreDelta {
            return .holding(
                RecommendationHold(
                    reason: .insignificantDelta,
                    proof: proof,
                    confidence: snapshot.overallConfidence,
                    freshness: snapshot.freshness
                )
            )
        }

        return .recommended(
            RecommendationSummary(
                selectedCandidateID: best.candidateID,
                proof: proof,
                confidence: snapshot.overallConfidence,
                freshness: snapshot.freshness
            )
        )
    }

    public func makeProof(
        best: ProbeCandidateResult,
        runnerUp: ProbeCandidateResult?,
        snapshot: ResultSnapshot
    ) -> ProofPayload {
        let deltas = proofDeltas(best: best, runnerUp: runnerUp)
        return ProofPayload(
            title: "Why this?",
            subtitle: runnerUp == nil ? "Only one candidate was measurable." : "Compared against the next-best option.",
            deltas: deltas,
            confidence: snapshot.overallConfidence,
            freshness: snapshot.freshness,
            isPartial: snapshot.isPartial
        )
    }

    private func proofDeltas(best: ProbeCandidateResult, runnerUp: ProbeCandidateResult?) -> [ProofDelta] {
        guard let runnerUp else { return [] }

        let bestMetrics = Dictionary(uniqueKeysWithValues: best.metrics.map { ($0.name, $0) })
        let runnerMetrics = Dictionary(uniqueKeysWithValues: runnerUp.metrics.map { ($0.name, $0) })
        let metricNames = Array(Set(bestMetrics.keys).union(runnerMetrics.keys)).sorted()

        return metricNames.compactMap { name in
            guard let bestMetric = bestMetrics[name], let runnerMetric = runnerMetrics[name] else { return nil }
            return ProofDelta(
                metricName: name,
                currentValue: runnerMetric.value,
                candidateValue: bestMetric.value,
                unit: bestMetric.unit,
                betterIsHigher: bestMetric.betterIsHigher,
                note: bestMetric.betterIsHigher == runnerMetric.betterIsHigher ? nil : "Metric direction differs."
            )
        }
    }
}
