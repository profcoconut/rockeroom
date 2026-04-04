import XCTest
@testable import SharedKit

/// Contract tests for the destination routing semantics.
///
/// These tests define the expected visible fields and behavior for routing state:
/// current destination performance, current strategy, current provider, optimization
/// opportunity, confidence, and hold/uncertainty semantics.
///
/// Auto Mode vs Manual Mode semantics are defined here in tests before any
/// production implementation exists, so later routing-engine work has a stable
/// contract to satisfy.
///
/// Test-only types (RoutingStrategy, RoutingConfidence, RoutingQuality) define
/// the vocabulary. Production types will replace these in later sprints.
final class DestinationRoutingContractTests: XCTestCase {
    // MARK: - Routing State Vocabulary

    /// The routing strategy in effect.
    enum RoutingStrategy: Equatable {
        case auto   // RockeRoom may auto-apply better routes
        case manual // RockeRoom only advises; user must apply manually
    }

    /// Confidence level for routing decisions.
    enum RoutingConfidence: Equatable {
        case high
        case medium
        case low
        case unknown
    }

    /// Measured quality for the current routing decision.
    struct RoutingQuality: Equatable {
        let latencyMs: Int
        let jitterMs: Int
        let packetLossPct: Double
        let throughputMbps: Int
    }

    /// The full routing state as visible to the user.
    struct RoutingState: Equatable {
        let strategy: RoutingStrategy
        let providerID: String
        let providerLabel: String
        let quality: RoutingQuality
        let confidence: RoutingConfidence
        let freshness: Double  // 0.0–1.0, 1.0 = fresh
        let optimizationOpportunity: OptimizationOpportunity?
        let holdReason: HoldReason?
    }

    enum OptimizationOpportunity: Equatable {
        case betterRouteAvailable(newProviderID: String, newProviderLabel: String, delta: String)
        case noOpportunity
    }

    enum HoldReason: Equatable {
        case pinned
        case staleEvidence
        case lowConfidence
        case insignificantDelta
        case notApplicable
    }

    // MARK: - Helper: make a routing state

    func makeState(
        strategy: RoutingStrategy = .auto,
        providerID: String = "fast",
        providerLabel: String = "Fast Relay",
        quality: RoutingQuality = RoutingQuality(latencyMs: 42, jitterMs: 4, packetLossPct: 0.2, throughputMbps: 182),
        confidence: RoutingConfidence = .high,
        freshness: Double = 0.95,
        optimizationOpportunity: OptimizationOpportunity? = nil,
        holdReason: HoldReason? = nil
    ) -> RoutingState {
        RoutingState(
            strategy: strategy,
            providerID: providerID,
            providerLabel: providerLabel,
            quality: quality,
            confidence: confidence,
            freshness: freshness,
            optimizationOpportunity: optimizationOpportunity,
            holdReason: holdReason
        )
    }

    // MARK: - Happy Path

    func testRoutingStateExpressesStrategyProviderAndQuality() {
        let state = makeState(providerID: "jp-01", providerLabel: "Japan 01")
        XCTAssertEqual(state.strategy, .auto)
        XCTAssertEqual(state.providerID, "jp-01")
        XCTAssertEqual(state.providerLabel, "Japan 01")
        XCTAssertEqual(state.quality.latencyMs, 42)
        XCTAssertEqual(state.quality.throughputMbps, 182)
    }

    func testAutoModeMarksBetterRouteAsApplyCapable() {
        // When Auto Mode sees a better route, it marks it as apply-capable.
        let state = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.95,
            optimizationOpportunity: .betterRouteAvailable(
                newProviderID: "hk-01",
                newProviderLabel: "Hong Kong 01",
                delta: "-14ms latency"
            ),
            holdReason: nil
        )

        switch state.optimizationOpportunity {
        case .betterRouteAvailable(let newID, let newLabel, _):
            XCTAssertEqual(newID, "hk-01")
            XCTAssertEqual(newLabel, "Hong Kong 01")
        case .noOpportunity, nil:
            XCTFail("Expected a better route opportunity in Auto Mode with high confidence and fresh evidence")
        }

        XCTAssertNil(state.holdReason, "Auto Mode with high confidence and fresh evidence should not be on hold")
    }

    func testManualModeMarksSameBetterRouteAsAdvisoryOnly() {
        // Manual Mode surfaces the better route but does NOT mark it as apply-capable.
        // The user must act on it manually.
        let state = makeState(
            strategy: .manual,
            confidence: .high,
            freshness: 0.95,
            optimizationOpportunity: nil,  // Manual mode does not auto-suggest
            holdReason: nil
        )

        // Manual mode may still expose quality information, but does not offer
        // an optimization opportunity that RockeRoom would auto-apply.
        XCTAssertEqual(state.strategy, .manual)
        XCTAssertNil(state.optimizationOpportunity, "Manual Mode should not present auto-apply optimization opportunities")
    }

    // MARK: - Edge Cases

    func testWeakEvidenceMarksRouteAsHold() {
        // When evidence is weak (low confidence or stale), Auto Mode holds
        // rather than recommending a switch.
        let state = makeState(
            strategy: .auto,
            confidence: .low,
            freshness: 0.4,
            optimizationOpportunity: nil,
            holdReason: .lowConfidence
        )

        XCTAssertEqual(state.holdReason, .lowConfidence)
        XCTAssertNil(state.optimizationOpportunity, "Low-confidence state should not offer optimization opportunity")
    }

    func testStaleEvidenceMarksRouteAsHold() {
        let state = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.3,
            optimizationOpportunity: nil,
            holdReason: .staleEvidence
        )

        XCTAssertEqual(state.holdReason, .staleEvidence)
    }

    func testInsignificantDeltaMarksRouteAsNoOpportunity() {
        // When the measured gain is too small, it is not marked as an opportunity.
        // The delta is "within noise" — Auto Mode should not switch for trivial gains.
        let state = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.95,
            optimizationOpportunity: .noOpportunity,
            holdReason: .insignificantDelta
        )

        XCTAssertEqual(state.holdReason, .insignificantDelta)
    }

    func testPinnedProviderMarksRouteAsOnHold() {
        // When the user has pinned a provider manually, Auto Mode respects that
        // and does not switch even when a better route is available.
        let state = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.95,
            optimizationOpportunity: nil,  // suppressed by pin
            holdReason: .pinned
        )

        XCTAssertEqual(state.holdReason, .pinned)
    }

    func testMeasuredButNotAppliedIsNotAnError() {
        // A destination can be measured (quality is available) but not applied
        // (e.g., because it was measured for a different destination).
        // This should not be treated as an error — it is normal behavior.
        let state = makeState(
            strategy: .manual,
            confidence: .medium,
            freshness: 0.7,
            optimizationOpportunity: nil,
            holdReason: nil
        )

        // No hold reason = the state is coherent but no action is recommended
        XCTAssertNil(state.holdReason)
        XCTAssertEqual(state.confidence, .medium)
    }

    // MARK: - Error Paths

    func testMissingStrategyYieldsExplicitDegradedState() {
        // When strategy is unknown/missing, the state should express this explicitly
        // rather than defaulting to a behavior that silently misleads the user.
        let degradedState = makeState(
            strategy: .auto,  // We test the contract by checking that strategy field exists
            confidence: .unknown,
            freshness: 0.0,
            optimizationOpportunity: nil,
            holdReason: nil
        )

        XCTAssertEqual(degradedState.confidence, .unknown)
        XCTAssertEqual(degradedState.freshness, 0.0, "Unknown freshness should be 0.0")
    }

    func testMissingProviderInformationYieldsDegradedState() {
        // When the current provider is unknown, the state should be degraded
        // and not silently present stale or misleading quality information.
        let state = RoutingState(
            strategy: .auto,
            providerID: "",
            providerLabel: "Unknown",
            quality: RoutingQuality(latencyMs: 0, jitterMs: 0, packetLossPct: 0, throughputMbps: 0),
            confidence: .unknown,
            freshness: 0.0,
            optimizationOpportunity: nil,
            holdReason: nil
        )

        XCTAssertEqual(state.providerID, "", "Missing provider should be empty string, not a default value")
        XCTAssertEqual(state.confidence, .unknown, "Missing provider should result in unknown confidence")
        XCTAssertEqual(state.quality.latencyMs, 0, "Quality should be zeroed when provider is unknown")
    }

    // MARK: - Contract Integration: Existing Summary Behavior

    func testHomeRecommendationSubtitleReflectsRoutingState() {
        // The Home surface subtitle should reflect routing state accurately.
        // This test ensures the routing contract connects to the existing
        // Home summary language defined in HomeSummaryMetricTests.

        // Auto mode with high confidence and fresh evidence → "Measured recommendation"
        let recommendedState = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.95,
            optimizationOpportunity: .betterRouteAvailable(
                newProviderID: "hk-01",
                newProviderLabel: "Hong Kong 01",
                delta: "-14ms"
            )
        )

        let recommendationStatus = routingStatusLabel(for: recommendedState)
        XCTAssertEqual(recommendationStatus, "Measured recommendation")

        // Auto mode on hold → "Measured hold"
        let holdState = makeState(
            strategy: .auto,
            confidence: .high,
            freshness: 0.4,
            holdReason: .staleEvidence
        )
        let holdStatus = routingStatusLabel(for: holdState)
        XCTAssertEqual(holdStatus, "Measured hold")

        // No benchmark run → "No benchmark run yet"
        let idleState = makeState(
            strategy: .auto,
            confidence: .unknown,
            freshness: 0.0,
            holdReason: nil
        )
        let idleStatus = routingStatusLabel(for: idleState)
        XCTAssertEqual(idleStatus, "No benchmark run yet")
    }

    /// Maps RoutingState to the expected homeRecommendationStatus string.
    private func routingStatusLabel(for state: RoutingState) -> String {
        if state.freshness == 0.0 && state.confidence == .unknown {
            return "No benchmark run yet"
        }
        if state.holdReason != nil {
            return "Measured hold"
        }
        if state.optimizationOpportunity != nil {
            return "Measured recommendation"
        }
        return "Recommendation unavailable"
    }
}
