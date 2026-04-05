import XCTest

@testable import SharedKit

/// Contract tests for the current routing semantics that later destination-aware work
/// must preserve. These tests intentionally assert through production seams rather than
/// test-local routing models.
final class DestinationRoutingContractTests: XCTestCase {
    func testRecommendedRouteCarriesCurrentProviderTruthAndProof() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.91,
            bestScore: 0.95,
            runnerUpScore: 0.78
        )
        let recommendationState = RecommendationPolicy().evaluate(snapshot: snapshot, pinState: .none)

        guard case .recommended(let summary) = recommendationState else {
            return XCTFail("Expected a recommendation for fresh, confident evidence.")
        }

        XCTAssertEqual(summary.selectedCandidateID, "fast")
        XCTAssertEqual(summary.confidence, 0.91, accuracy: 0.001)
        XCTAssertEqual(summary.freshness, 0.95, accuracy: 0.001)
        XCTAssertEqual(summary.proof.deltas.first?.metricName, "Latency")

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: .none
        )

        XCTAssertEqual(projection.primaryState, .current)
        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card in the evidence projection.")
        }
        XCTAssertEqual(currentCard.candidateID, "fast")
        XCTAssertEqual(currentCard.markers, [.current, .recommended])
    }

    func testPinnedOverrideProducesExplicitHoldAndPinnedCurrentCard() {
        let snapshot = makeSnapshot(
            freshness: 0.94,
            overallConfidence: 0.9,
            bestScore: 0.95,
            runnerUpScore: 0.78
        )
        let pinState = PinState.pinned(candidateID: "stable")
        let recommendationState = RecommendationPolicy().evaluate(snapshot: snapshot, pinState: pinState)

        guard case .holding(let hold) = recommendationState else {
            return XCTFail("Expected a hold when a non-best provider is pinned.")
        }

        XCTAssertEqual(hold.reason, .pinned)
        XCTAssertNotNil(hold.proof)

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: pinState
        )

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card in the evidence projection.")
        }
        XCTAssertEqual(currentCard.candidateID, "stable")
        XCTAssertEqual(currentCard.markers, [.current, .pinned])
    }

    func testStaleEvidenceProducesExplicitHoldAndStaleProjection() {
        let snapshot = makeSnapshot(
            freshness: 0.2,
            overallConfidence: 0.91,
            bestScore: 0.95,
            runnerUpScore: 0.78
        )
        let recommendationState = RecommendationPolicy(staleFreshnessThreshold: 0.5).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        guard case .holding(let hold) = recommendationState else {
            return XCTFail("Expected a hold for stale evidence.")
        }

        XCTAssertEqual(hold.reason, .staleData)
        XCTAssertEqual(hold.freshness, 0.2, accuracy: 0.001)

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: .none
        )

        XCTAssertEqual(projection.primaryState, .partial)
        XCTAssertTrue(projection.stateBadges.contains(.stale))
    }

    func testLowConfidenceProducesExplicitHoldWithoutRecommendationMarker() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.3,
            bestScore: 0.95,
            runnerUpScore: 0.78
        )
        let recommendationState = RecommendationPolicy(minimumConfidence: 0.8).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        guard case .holding(let hold) = recommendationState else {
            return XCTFail("Expected a hold when confidence is below threshold.")
        }

        XCTAssertEqual(hold.reason, .lowConfidence)

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: .none
        )

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card in the evidence projection.")
        }
        XCTAssertFalse(currentCard.markers.contains(.recommended))
    }

    func testIncoherentRecommendationDegradesProjectionInsteadOfSilentlyDroppingProviderTruth() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.91,
            bestScore: 0.95,
            runnerUpScore: 0.78
        )
        let proof = RecommendationPolicy().makeProof(
            best: snapshot.bestCandidate!,
            runnerUp: snapshot.runnerUpCandidate,
            snapshot: snapshot
        )
        let malformedState = RecommendationState.recommended(
            RecommendationSummary(
                selectedCandidateID: "missing",
                proof: proof,
                confidence: 0.91,
                freshness: 0.95
            )
        )

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: malformedState,
            pinState: .none
        )

        XCTAssertEqual(projection.primaryState, .degraded)
        XCTAssertTrue(projection.stateBadges.contains(.degraded))
        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card when degrading malformed recommendation state.")
        }
        XCTAssertEqual(currentCard.candidateID, "fast")
        XCTAssertEqual(currentCard.markers, [.current])
    }

    private func makeSnapshot(
        freshness: Double,
        overallConfidence: Double,
        bestScore: Double,
        runnerUpScore: Double
    ) -> ResultSnapshot {
        ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "fast",
                    label: "Fast Relay",
                    metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: bestScore,
                    confidence: overallConfidence,
                    freshness: freshness
                ),
                ProbeCandidateResult(
                    candidateID: "stable",
                    label: "Stable Relay",
                    metrics: [ProbeMetric(name: "Latency", value: 150, unit: "ms", betterIsHigher: false)],
                    score: runnerUpScore,
                    confidence: overallConfidence,
                    freshness: freshness
                )
            ],
            selectedCandidateID: "fast",
            overallConfidence: overallConfidence,
            freshness: freshness,
            isPartial: freshness < 0.5
        )
    }
}
