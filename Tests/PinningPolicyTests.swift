import XCTest

@testable import SharedKit

final class PinningPolicyTests: XCTestCase {
    func testPinnedProviderDoesNotAutoSwitch() {
        let policy = RecommendationPolicy()
        let snapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "latency", value: 20, unit: "ms", betterIsHigher: false)],
                    score: 0.99,
                    confidence: 0.99,
                    freshness: 1.0
                ),
                ProbeCandidateResult(
                    candidateID: "pinned",
                    label: "Pinned",
                    metrics: [ProbeMetric(name: "latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: 0.25,
                    confidence: 0.70,
                    freshness: 1.0
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: 0.99,
            freshness: 1.0,
            isPartial: false
        )

        let state = policy.evaluate(snapshot: snapshot, pinState: .pinned(candidateID: "pinned"))

        switch state {
        case .holding(let hold):
            XCTAssertEqual(hold.reason, .pinned)
            XCTAssertNotNil(hold.proof)
        default:
            XCTFail("Expected pinned hold")
        }
    }
}
