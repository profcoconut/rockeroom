import Foundation

@MainActor
final class LiveE2ERunner: ObservableObject {
    struct State: Equatable {
        struct RankedCandidate: Equatable {
            let candidateID: String
            let title: String
        }

        let hasImportedSubscription: Bool
        let importErrorMessage: String?
        let isImporting: Bool
        let hasBenchmarkResults: Bool
        let isBenchmarkInFlight: Bool
        let selectedTab: MainTab
        let refreshHintText: String?
        let pinnedCandidateID: String?
        let rankedCandidates: [RankedCandidate]
    }

    struct Actions {
        let importSubscription: (String) -> Void
        let runBenchmark: () -> Void
        let selectTab: (MainTab) -> Void
        let pinCandidate: (String) -> Void
        let unpinCandidate: () -> Void
    }

    enum Action: Equatable {
        case importSubscription(String)
        case runBenchmark
        case selectTab(MainTab)
        case pinCandidate(String)
        case unpinCandidate
    }

    let scenario: LiveE2EScenario?
    private var executedActionKeys = Set<String>()

    init(scenario: LiveE2EScenario? = LiveE2EScenario.resolved()) {
        self.scenario = scenario
    }

    func advance(state: State, actions: Actions) {
        guard let action = nextAction(for: state) else { return }
        executedActionKeys.insert(action.key)

        switch action {
        case .importSubscription(let link):
            actions.importSubscription(link)
        case .runBenchmark:
            actions.runBenchmark()
        case .selectTab(let tab):
            actions.selectTab(tab)
        case .pinCandidate(let candidateID):
            actions.pinCandidate(candidateID)
        case .unpinCandidate:
            actions.unpinCandidate()
        }
    }

    func nextAction(for state: State) -> Action? {
        guard let scenario else { return nil }

        switch scenario.kind {
        case .importHome:
            return nextImportAction(for: state)
        case .benchmarkHome:
            return nextBenchmarkAction(for: state)
        case .expertConsole:
            return nextExpertConsoleAction(for: state)
        case .pinStable:
            return nextPinStableAction(for: state)
        case .pinUnpinHome:
            return nextPinUnpinHomeAction(for: state)
        case .marketplace:
            return nextMarketplaceAction(for: state)
        case .staleHint:
            return nextStaleHintAction(for: state)
        case .staleRefresh:
            return nextStaleRefreshAction(for: state)
        case .tunnelFailure:
            return nextTunnelFailureAction(for: state)
        case .tunnelRecovery:
            return nextTunnelRecoveryAction(for: state)
        }
    }

    private func nextImportAction(for state: State) -> Action? {
        if !state.hasImportedSubscription && !state.isImporting && state.importErrorMessage == nil {
            return unresolved(.importSubscription(scenario?.subscriptionLink ?? ""))
        }

        if state.hasImportedSubscription && state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextBenchmarkAction(for state: State) -> Action? {
        if let action = nextImportAction(for: state) {
            return action
        }

        if state.hasImportedSubscription && !state.hasBenchmarkResults && !state.isBenchmarkInFlight {
            return unresolved(.runBenchmark)
        }

        if state.hasBenchmarkResults && state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextExpertConsoleAction(for state: State) -> Action? {
        if let action = nextBenchmarkAction(for: state), action != .selectTab(.home) {
            return action
        }

        if state.hasBenchmarkResults && state.selectedTab != .expertConsole {
            return unresolved(.selectTab(.expertConsole))
        }

        return nil
    }

    private func nextPinStableAction(for state: State) -> Action? {
        if let action = nextExpertConsoleAction(for: state), action != .selectTab(.expertConsole) {
            return action
        }

        if state.hasBenchmarkResults && state.selectedTab != .expertConsole {
            return unresolved(.selectTab(.expertConsole))
        }

        guard state.pinnedCandidateID == nil else { return nil }
        guard let candidateID = preferredPinCandidateID(in: state.rankedCandidates) else { return nil }
        return unresolved(.pinCandidate(candidateID))
    }

    private func nextPinUnpinHomeAction(for state: State) -> Action? {
        if !hasExecuted(.pinCandidate("pending")) {
            if let action = nextPinStableAction(for: state) {
                return action
            }
            return nil
        }

        if state.pinnedCandidateID != nil {
            return unresolved(.unpinCandidate)
        }

        if state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextMarketplaceAction(for state: State) -> Action? {
        if let action = nextBenchmarkAction(for: state), action != .selectTab(.home) {
            return action
        }

        if state.hasBenchmarkResults && state.selectedTab != .marketplace {
            return unresolved(.selectTab(.marketplace))
        }

        return nil
    }

    private func nextStaleHintAction(for state: State) -> Action? {
        if !state.hasImportedSubscription || !state.hasBenchmarkResults {
            return nextBenchmarkAction(for: state)
        }

        if state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextStaleRefreshAction(for state: State) -> Action? {
        if let action = nextStaleHintAction(for: state), action != .selectTab(.home) {
            return action
        }

        if state.refreshHintText != nil && !state.isBenchmarkInFlight {
            return unresolved(.runBenchmark)
        }

        if state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextTunnelFailureAction(for state: State) -> Action? {
        if let action = nextImportAction(for: state) {
            return action
        }

        if state.hasImportedSubscription && !state.hasBenchmarkResults && !state.isBenchmarkInFlight && state.importErrorMessage == nil {
            return unresolved(.runBenchmark)
        }

        if state.hasImportedSubscription && state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func nextTunnelRecoveryAction(for state: State) -> Action? {
        if !state.hasImportedSubscription {
            return nextImportAction(for: state)
        }

        if !state.hasBenchmarkResults && !state.isBenchmarkInFlight {
            return unresolved(.runBenchmark)
        }

        if state.selectedTab != .home {
            return unresolved(.selectTab(.home))
        }

        return nil
    }

    private func unresolved(_ action: Action) -> Action? {
        hasExecuted(action) ? nil : action
    }

    private func hasExecuted(_ action: Action) -> Bool {
        executedActionKeys.contains(action.key)
    }

    private func preferredPinCandidateID(in candidates: [State.RankedCandidate]) -> String? {
        if let stable = candidates.first(where: { $0.title.localizedCaseInsensitiveContains("stable") }) {
            return stable.candidateID
        }

        if candidates.count > 1 {
            return candidates[1].candidateID
        }

        return candidates.first?.candidateID
    }
}

private extension LiveE2ERunner.Action {
    var key: String {
        switch self {
        case .importSubscription:
            return "import"
        case .runBenchmark:
            return "benchmark"
        case .selectTab(let tab):
            return "tab:\(tab)"
        case .pinCandidate:
            return "pin"
        case .unpinCandidate:
            return "unpin"
        }
    }
}
