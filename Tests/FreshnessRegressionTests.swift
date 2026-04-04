import XCTest

@testable import SharedKit

final class FreshnessRegressionTests: XCTestCase {
    func testStaleSnapshotForcesHoldEvenWhenScoreIsHigh() {
        let policy = RecommendationPolicy(staleFreshnessThreshold: 0.5)
        let snapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "latency", value: 20, unit: "ms", betterIsHigher: false)],
                    score: 0.99,
                    confidence: 0.99,
                    freshness: 0.1
                ),
                ProbeCandidateResult(
                    candidateID: "runnerUp",
                    label: "RunnerUp",
                    metrics: [ProbeMetric(name: "latency", value: 200, unit: "ms", betterIsHigher: false)],
                    score: 0.10,
                    confidence: 0.10,
                    freshness: 0.1
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: 0.99,
            freshness: 0.1,
            isPartial: false
        )

        let state = policy.evaluate(snapshot: snapshot, pinState: .none)

        switch state {
        case .holding(let hold):
            XCTAssertEqual(hold.reason, .staleData)
            XCTAssertNotNil(hold.proof)
        default:
            XCTFail("Expected stale-data hold")
        }
    }

    func testRefreshCoordinatorMarksRunningSnapshotAsRefreshableWhenAgeDecaysFreshness() {
        let coordinator = RefreshCoordinator(currentWindow: 60, staleWindow: 120, staleFreshnessThreshold: 0.5)
        let now = Date(timeIntervalSince1970: 500)
        let snapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            generatedAt: Date(timeIntervalSince1970: 400),
            candidates: [
                ProbeCandidateResult(
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "latency", value: 20, unit: "ms", betterIsHigher: false)],
                    score: 0.99,
                    confidence: 0.99,
                    freshness: 0.95
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: 0.99,
            freshness: 0.95,
            isPartial: false
        )

        let assessment = coordinator.evaluate(
            snapshot: snapshot,
            tunnelStatus: ClashAdapterStatus(state: .running),
            trigger: .restore,
            now: now
        )

        XCTAssertEqual(assessment.evidenceState, .staleUsable)
        XCTAssertEqual(assessment.refreshAvailability, .recommended)
        XCTAssertEqual(assessment.snapshot?.freshness ?? -1, 1.0 / 3.0, accuracy: 0.001)
    }

    func testRefreshCoordinatorRequiresExplicitRefreshWhenTunnelIsStopped() {
        let coordinator = RefreshCoordinator(currentWindow: 60, staleWindow: 120, staleFreshnessThreshold: 0.5)
        let now = Date(timeIntervalSince1970: 500)
        let snapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            generatedAt: Date(timeIntervalSince1970: 400),
            candidates: [
                ProbeCandidateResult(
                    candidateID: "best",
                    label: "Best",
                    metrics: [ProbeMetric(name: "latency", value: 20, unit: "ms", betterIsHigher: false)],
                    score: 0.99,
                    confidence: 0.99,
                    freshness: 0.95
                )
            ],
            selectedCandidateID: "best",
            overallConfidence: 0.99,
            freshness: 0.95,
            isPartial: false
        )

        let assessment = coordinator.evaluate(
            snapshot: snapshot,
            tunnelStatus: ClashAdapterStatus(state: .stopped),
            trigger: .restore,
            now: now
        )

        XCTAssertEqual(assessment.evidenceState, .staleHold)
        XCTAssertEqual(assessment.refreshAvailability, .explicitOnly)
    }
}
