import XCTest

@testable import SharedKit

/// Characterization tests for the current automatic recommendation policy. These tests
/// lock the existing automatic-vs-user-override semantics without introducing a second
/// policy implementation in the test target.
final class RoutingOptimizationPolicyTests: XCTestCase {
    func testAutomaticRecommendationSelectsBestCandidateWhenEvidenceIsStrongAndFresh() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.9,
            bestScore: 0.92,
            runnerUpScore: 0.60
        )

        let state = RecommendationPolicy().evaluate(snapshot: snapshot, pinState: .none)

        guard case .recommended(let summary) = state else {
            return XCTFail("Expected an automatic recommendation for fresh, strong evidence.")
        }
        XCTAssertEqual(summary.selectedCandidateID, "best")
    }

    func testPinnedProviderSuppressesAutomaticSwitching() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.9,
            bestScore: 0.92,
            runnerUpScore: 0.60
        )

        let state = RecommendationPolicy().evaluate(
            snapshot: snapshot,
            pinState: .pinned(candidateID: "runnerUp")
        )

        guard case .holding(let hold) = state else {
            return XCTFail("Expected a hold when user override is active.")
        }
        XCTAssertEqual(hold.reason, .pinned)
        XCTAssertNotNil(hold.proof)
    }

    func testStaleEvidenceBlocksAutomaticRecommendation() {
        let snapshot = makeSnapshot(
            freshness: 0.3,
            overallConfidence: 0.9,
            bestScore: 0.92,
            runnerUpScore: 0.60
        )

        let state = RecommendationPolicy(staleFreshnessThreshold: 0.5).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        guard case .holding(let hold) = state else {
            return XCTFail("Expected a stale-data hold.")
        }
        XCTAssertEqual(hold.reason, .staleData)
    }

    func testLowConfidenceBlocksAutomaticRecommendation() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.4,
            bestScore: 0.92,
            runnerUpScore: 0.60
        )

        let state = RecommendationPolicy(minimumConfidence: 0.8).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        guard case .holding(let hold) = state else {
            return XCTFail("Expected a low-confidence hold.")
        }
        XCTAssertEqual(hold.reason, .lowConfidence)
    }

    func testInsignificantDeltaBlocksAutomaticRecommendation() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            overallConfidence: 0.9,
            bestScore: 0.51,
            runnerUpScore: 0.50
        )

        let state = RecommendationPolicy(minimumScoreDelta: 0.12).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        guard case .holding(let hold) = state else {
            return XCTFail("Expected an insignificant-delta hold.")
        }
        XCTAssertEqual(hold.reason, .insignificantDelta)
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
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "Latency", value: 30, unit: "ms", betterIsHigher: false)],
                    score: bestScore,
                    confidence: overallConfidence,
                    freshness: freshness
                ),
                ProbeCandidateResult(
                    candidateID: "runnerUp",
                    label: "RunnerUp",
                    metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: runnerUpScore,
                    confidence: overallConfidence,
                    freshness: freshness
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: overallConfidence,
            freshness: freshness,
            isPartial: false
        )
    }
}
