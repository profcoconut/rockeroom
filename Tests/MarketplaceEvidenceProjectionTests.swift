import Foundation
import XCTest

@testable import SharedKit

final class MarketplaceEvidenceProjectionTests: XCTestCase {
    func testProjectionUsesRecommendedCandidateAndProofForCurrentSnapshot() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            isPartial: false
        )
        let recommendationState = RecommendationPolicy().evaluate(snapshot: snapshot, pinState: .none)

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: .none
        )

        XCTAssertEqual(projection.primaryState, .current)
        XCTAssertTrue(projection.stateBadges.isEmpty)
        XCTAssertEqual(projection.cards.count, 2)

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card")
        }
        XCTAssertEqual(currentCard.candidateID, "fast")
        XCTAssertEqual(currentCard.markers, [.current, .recommended])
        guard let proof = currentCard.proof, let firstDelta = proof.deltas.first else {
            return XCTFail("Expected proof on current card")
        }
        XCTAssertEqual(firstDelta.metricName, "Latency")
        XCTAssertEqual(firstDelta.currentValue, 150, accuracy: 0.001)
        XCTAssertEqual(firstDelta.candidateValue, 120, accuracy: 0.001)
        XCTAssertEqual(projection.featuredProof, currentCard.proof)
    }

    func testProjectionMarksPinnedCandidateAsCurrentAndPinned() {
        let snapshot = makeSnapshot(
            freshness: 0.94,
            isPartial: false
        )
        let pinState = PinState.pinned(candidateID: "stable")
        let recommendationState = RecommendationPolicy().evaluate(snapshot: snapshot, pinState: pinState)

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: pinState
        )

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card")
        }
        XCTAssertEqual(currentCard.candidateID, "stable")
        XCTAssertEqual(currentCard.markers, [.current, .pinned])
        XCTAssertNotNil(currentCard.proof)
        XCTAssertTrue(projection.stateBadges.isEmpty)
    }

    func testProjectionReturnsEmptyStateWhenNoSnapshotExists() {
        let projection = EvidenceProjection.project(
            snapshot: nil,
            recommendationState: .idle,
            pinState: .none
        )

        XCTAssertEqual(projection.primaryState, .empty)
        XCTAssertTrue(projection.cards.isEmpty)
        XCTAssertEqual(projection.emptyMessage, "Run Benchmark to collect marketplace evidence.")
    }

    func testProjectionMarksStaleAndPartialSnapshots() {
        let snapshot = makeSnapshot(
            freshness: 0.2,
            isPartial: true
        )
        let recommendationState = RecommendationPolicy(staleFreshnessThreshold: 0.5).evaluate(
            snapshot: snapshot,
            pinState: .none
        )

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: recommendationState,
            pinState: .none
        )

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card")
        }
        XCTAssertEqual(projection.primaryState, .partial)
        XCTAssertTrue(projection.stateBadges.contains(.partial))
        XCTAssertTrue(projection.stateBadges.contains(.stale))
        XCTAssertEqual(currentCard.stateBadges, [.stale, .partial])
        XCTAssertNotNil(currentCard.proof)
    }

    func testProjectionFallsBackToBestCandidateWhenPinnedCandidateIsMissing() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            isPartial: false
        )

        let projection = EvidenceProjection.project(
            snapshot: snapshot,
            recommendationState: .idle,
            pinState: .pinned(candidateID: "missing")
        )

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card")
        }
        XCTAssertEqual(projection.primaryState, .degraded)
        XCTAssertTrue(projection.stateBadges.contains(.degraded))
        XCTAssertEqual(currentCard.candidateID, "fast")
        XCTAssertEqual(currentCard.markers, [.current])
    }

    func testProjectionDegradesWhenRecommendationReferencesMissingCandidate() {
        let snapshot = makeSnapshot(
            freshness: 0.95,
            isPartial: false
        )
        let policy = RecommendationPolicy()
        let proof = policy.makeProof(
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

        guard let currentCard = projection.cards.first(where: { $0.markers.contains(.current) }) else {
            return XCTFail("Expected a current card")
        }
        XCTAssertEqual(projection.primaryState, .degraded)
        XCTAssertTrue(projection.stateBadges.contains(.degraded))
        XCTAssertEqual(currentCard.candidateID, "fast")
        XCTAssertEqual(currentCard.markers, [.current])
    }

    private func makeSnapshot(freshness: Double, isPartial: Bool) -> ResultSnapshot {
        ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "fast",
                    label: "Fast Relay",
                    metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: 0.95,
                    confidence: 0.91,
                    freshness: freshness
                ),
                ProbeCandidateResult(
                    candidateID: "stable",
                    label: "Stable Relay",
                    metrics: [ProbeMetric(name: "Latency", value: 150, unit: "ms", betterIsHigher: false)],
                    score: 0.78,
                    confidence: 0.88,
                    freshness: freshness
                )
            ],
            selectedCandidateID: "fast",
            overallConfidence: 0.91,
            freshness: freshness,
            isPartial: isPartial
        )
    }
}
