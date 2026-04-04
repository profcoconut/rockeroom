import XCTest
@testable import SharedKit

/// Policy tests for routing optimization decisions.
///
/// These tests define when Auto Mode should apply a better route vs hold,
/// and what Manual Mode should vs should not do automatically.
///
/// The tests use the existing RecommendationPolicy + PinState to express
/// the routing optimization policy, extended with the new Auto vs Manual
/// strategy dimension.
final class RoutingOptimizationPolicyTests: XCTestCase {
    // MARK: - Routing Optimization Policy

    /// Represents the routing optimization decision produced by the policy.
    enum OptimizationDecision: Equatable {
        case apply(providerID: String)              // Auto Mode should switch to this provider
        case hold(reason: HoldReason)              // Should not switch
        case advisory(providerID: String, delta: String)  // Manual Mode: user decides
    }

    enum HoldReason: Equatable {
        case pinned
        case staleEvidence
        case lowConfidence
        case insignificantDelta
        case noCandidates
    }

    struct RoutingOptimizationPolicy {
        let minimumConfidence: Double
        let staleFreshnessThreshold: Double
        let minimumScoreDelta: Double

        init(
            minimumConfidence: Double = 0.65,
            staleFreshnessThreshold: Double = 0.5,
            minimumScoreDelta: Double = 0.12
        ) {
            self.minimumConfidence = minimumConfidence
            self.staleFreshnessThreshold = staleFreshnessThreshold
            self.minimumScoreDelta = minimumScoreDelta
        }

        /// Evaluates the optimization decision for Auto Mode.
        /// Returns whether to apply a better route given current evidence.
        func autoModeDecision(
            snapshot: ResultSnapshot,
            bestCandidateID: String,
            pinState: PinState
        ) -> OptimizationDecision {
            if snapshot.freshness < staleFreshnessThreshold {
                return .hold(reason: .staleEvidence)
            }

            if pinState.candidateID != nil {
                return .hold(reason: .pinned)
            }

            guard snapshot.overallConfidence >= minimumConfidence else {
                return .hold(reason: .lowConfidence)
            }

            let ordered = snapshot.candidates.sorted { $0.score > $1.score }
            guard let best = ordered.first else {
                return .hold(reason: .noCandidates)
            }
            guard let runnerUp = ordered.dropFirst().first else {
                return .apply(providerID: best.candidateID)
            }

            let delta = best.score - runnerUp.score
            if delta < minimumScoreDelta {
                return .hold(reason: .insignificantDelta)
            }

            return .apply(providerID: best.candidateID)
        }

        /// Evaluates the optimization decision for Manual Mode.
        /// Always advisory — never apply automatically.
        func manualModeDecision(snapshot: ResultSnapshot) -> OptimizationDecision {
            guard !snapshot.candidates.isEmpty else {
                return .hold(reason: .noCandidates)
            }
            let ordered = snapshot.candidates.sorted { $0.score > $1.score }
            guard let best = ordered.first, let runnerUp = ordered.dropFirst().first else {
                return .hold(reason: .noCandidates)
            }
            let delta = best.score - runnerUp.score
            let deltaFormatted = String(format: "%.0f%%", (delta * 100))
            return .advisory(providerID: best.candidateID, delta: deltaFormatted)
        }
    }

    // MARK: - Test Helpers

    func makeSnapshot(
        confidence: Double,
        freshness: Double,
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

    // MARK: - Auto Mode Tests

    func testAutoModeAppliesBetterRouteWhenEvidenceIsStrongAndFresh() {
        let policy = RoutingOptimizationPolicy()
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.95, bestScore: 0.92, runnerUpScore: 0.60)

        let decision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .none)

        switch decision {
        case .apply(let providerID):
            XCTAssertEqual(providerID, "best")
        default:
            XCTFail("Expected .apply with strong evidence, got: \(decision)")
        }
    }

    func testAutoModeHoldsWhenEvidenceIsStale() {
        let policy = RoutingOptimizationPolicy()
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.3, bestScore: 0.92, runnerUpScore: 0.60)

        let decision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .none)

        switch decision {
        case .hold(let reason):
            XCTAssertEqual(reason, .staleEvidence)
        default:
            XCTFail("Expected .hold when stale, got: \(decision)")
        }
    }

    func testAutoModeHoldsWhenProviderIsPinned() {
        let policy = RoutingOptimizationPolicy()
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.95, bestScore: 0.92, runnerUpScore: 0.60)

        let decision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .pinned(candidateID: "runnerUp"))

        switch decision {
        case .hold(let reason):
            XCTAssertEqual(reason, .pinned)
        default:
            XCTFail("Expected .hold when pinned, got: \(decision)")
        }
    }

    func testAutoModeHoldsWhenConfidenceIsLow() {
        let policy = RoutingOptimizationPolicy(minimumConfidence: 0.8)
        let snapshot = makeSnapshot(confidence: 0.4, freshness: 0.95, bestScore: 0.92, runnerUpScore: 0.60)

        let decision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .none)

        switch decision {
        case .hold(let reason):
            XCTAssertEqual(reason, .lowConfidence)
        default:
            XCTFail("Expected .hold when low confidence, got: \(decision)")
        }
    }

    func testAutoModeHoldsWhenDeltaIsInsignificant() {
        let policy = RoutingOptimizationPolicy(minimumScoreDelta: 0.12)
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.95, bestScore: 0.51, runnerUpScore: 0.50)

        let decision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .none)

        switch decision {
        case .hold(let reason):
            XCTAssertEqual(reason, .insignificantDelta)
        default:
            XCTFail("Expected .hold when delta is insignificant, got: \(decision)")
        }
    }

    // MARK: - Manual Mode Tests

    func testManualModeAlwaysAdvisoryNeverAutoApplies() {
        let policy = RoutingOptimizationPolicy()
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.95, bestScore: 0.92, runnerUpScore: 0.60)

        let decision = policy.manualModeDecision(snapshot: snapshot)

        switch decision {
        case .advisory(let providerID, let delta):
            XCTAssertEqual(providerID, "best")
            XCTAssertFalse(delta.isEmpty)
        case .apply:
            XCTFail("Manual Mode should never auto-apply")
        default:
            XCTFail("Expected .advisory, got: \(decision)")
        }
    }

    func testManualModeHoldsWhenNoCandidates() {
        let policy = RoutingOptimizationPolicy()
        let emptySnapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/sub")!,
            candidates: [],
            overallConfidence: 0,
            freshness: 0,
            isPartial: true
        )

        let decision = policy.manualModeDecision(snapshot: emptySnapshot)

        switch decision {
        case .hold(let reason):
            XCTAssertEqual(reason, .noCandidates)
        default:
            XCTFail("Expected .hold when no candidates, got: \(decision)")
        }
    }

    // MARK: - Auto vs Manual Contrast

    func testAutoModeAndManualModeDivergeOnSameSnapshot() {
        // Given the same snapshot, Auto and Manual should produce different decisions.
        // Auto: applies if evidence is strong
        // Manual: always advisory regardless of evidence strength
        let policy = RoutingOptimizationPolicy()
        let snapshot = makeSnapshot(confidence: 0.9, freshness: 0.95, bestScore: 0.92, runnerUpScore: 0.60)

        let autoDecision = policy.autoModeDecision(snapshot: snapshot, bestCandidateID: "best", pinState: .none)
        let manualDecision = policy.manualModeDecision(snapshot: snapshot)

        // Auto should apply
        XCTAssertEqual(autoDecision, .apply(providerID: "best"))
        // Manual should be advisory (never apply)
        XCTAssertEqual(manualDecision, .advisory(providerID: "best", delta: "32%"))
    }
}
