import XCTest

@testable import SharedKit

final class RecommendationPolicyTests: XCTestCase {
    func testRecommendationPolicySelectsBestFreshCandidate() {
        let policy = RecommendationPolicy()
        let snapshot = makeSnapshot(
            freshness: 1.0,
            confidence: 0.95,
            bestScore: 0.92,
            runnerUpScore: 0.60
        )

        let state = policy.evaluate(snapshot: snapshot, pinState: .none)

        switch state {
        case .recommended(let summary):
            XCTAssertEqual(summary.selectedCandidateID, "best")
            XCTAssertEqual(summary.proof.deltas.first?.metricName, "Latency")
        default:
            XCTFail("Expected recommendation")
        }
    }

    func testRecommendationPolicyHoldsWhenPinned() {
        let policy = RecommendationPolicy()
        let snapshot = makeSnapshot(
            freshness: 1.0,
            confidence: 0.95,
            bestScore: 0.95,
            runnerUpScore: 0.40
        )

        let state = policy.evaluate(snapshot: snapshot, pinState: .pinned(candidateID: "runnerUp"))

        switch state {
        case .holding(let hold):
            XCTAssertEqual(hold.reason, .pinned)
        default:
            XCTFail("Expected hold")
        }
    }

    func testRecommendationPolicyHoldsWhenConfidenceIsLow() {
        let policy = RecommendationPolicy(minimumConfidence: 0.8)
        let snapshot = makeSnapshot(
            freshness: 1.0,
            confidence: 0.4,
            bestScore: 0.95,
            runnerUpScore: 0.40
        )

        let state = policy.evaluate(snapshot: snapshot, pinState: .none)

        switch state {
        case .holding(let hold):
            XCTAssertEqual(hold.reason, .lowConfidence)
        default:
            XCTFail("Expected hold")
        }
    }

    private func makeSnapshot(
        freshness: Double,
        confidence: Double,
        bestScore: Double,
        runnerUpScore: Double
    ) -> ResultSnapshot {
        ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "Latency", value: 50, unit: "ms", betterIsHigher: false)],
                    score: bestScore,
                    confidence: confidence,
                    freshness: freshness
                ),
                ProbeCandidateResult(
                    candidateID: "runnerUp",
                    label: "RunnerUp",
                    metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: runnerUpScore,
                    confidence: confidence,
                    freshness: freshness
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: confidence,
            freshness: freshness,
            isPartial: false
        )
    }
}
