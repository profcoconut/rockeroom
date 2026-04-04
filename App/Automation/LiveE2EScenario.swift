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
