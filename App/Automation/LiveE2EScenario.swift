import Foundation

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

        // MARK: - Destination-Aware Routing Scenarios (Sprint 1 contract placeholders)

        /// Auto Mode: a better route is available and evidence is strong enough to apply automatically.
        case autoModeApply = "auto-mode-apply"
        /// Manual Mode: a better route is available but only advisory — user must confirm.
        case manualModeAdvisory = "manual-mode-advisory"
        /// Override or pin path: user has overridden the automatic recommendation.
        case overrideOrPin = "override-or-pin"
        /// Stale evidence path: the current route evidence is stale and a refresh is needed.
        case staleOrRefresh = "stale-or-refresh"
        /// Recovery path: a route reassignment failed and the app recovered to a safe state.
        case failedReassignment = "failed-reassignment"
    }

    let kind: Kind
    let subscriptionLink: String

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
            subscriptionLink: environment["ROCKEROOM_LIVE_E2E_LINK"] ?? "https://example.com/live-e2e"
        )
    }
}
