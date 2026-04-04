import Foundation
import SharedKit

struct LiveE2EScenario: Equatable {
    enum Kind: String, CaseIterable {
        case importHome = "import-home"
        case benchmarkHome = "benchmark-home"
        case expertConsole = "expert-console"
        case pinStable = "pin-stable"
        case pinUnpinHome = "pin-unpin-home"
        case marketplace = "marketplace"
        case staleHint = "stale-hint"
        case staleRefresh = "stale-refresh"
        case tunnelFailure = "tunnel-failure"
        case tunnelRecovery = "tunnel-recovery"

        // MARK: - Destination-Aware Routing Scenarios (Sprint 1 contract analogs)

        /// Auto Mode analogue: replay to the current recommended Home state.
        case autoModeApply = "auto-mode-apply"
        /// Manual Mode analogue: benchmarked state is visible in Expert Console for inspection.
        case manualModeAdvisory = "manual-mode-advisory"
        /// Override or pin analogue: user-controlled pinning suppresses the automatic recommendation.
        case overrideOrPin = "override-or-pin"
        /// Stale evidence analogue: the app restores to a stale hold and surfaces a refresh hint.
        case staleOrRefresh = "stale-or-refresh"
        /// Recovery analogue: a failed change lands in a recoverable Home failure state.
        case failedReassignment = "failed-reassignment"
    }

    let kind: Kind
    let subscriptionLink: String

    /// Optional persisted destination routing assignments to seed into the app.
    /// When nil, no destination assignment state is seeded (legacy behavior).
    var destinationAssignment: DestinationRoutingAssignments? = nil

    static func resolved(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> LiveE2EScenario? {
        guard
            let rawValue = environment["ROCKEROOM_LIVE_E2E_SCENARIO"],
            let kind = Kind(rawValue: rawValue)
        else {
            return nil
        }

        return LiveE2EScenario(
            kind: kind,
            subscriptionLink: environment["ROCKEROOM_LIVE_E2E_LINK"] ?? "https://example.com/live-e2e",
            destinationAssignment: nil
        )
    }
}
