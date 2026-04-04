import XCTest

@testable import RockeRoom

@MainActor
final class LiveE2EScenarioTests: XCTestCase {
    func testResolvedScenarioParsesKnownEnvironmentKeys() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "expert-console",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )

        XCTAssertEqual(
            scenario,
            LiveE2EScenario(kind: .expertConsole, subscriptionLink: "https://example.com/live")
        )
    }

    func testResolvedScenarioIgnoresUnknownScenarioName() {
        XCTAssertNil(
            LiveE2EScenario.resolved(
                from: ["ROCKEROOM_LIVE_E2E_SCENARIO": "unknown-scenario"]
            )
        )
    }

    // MARK: - Destination-Aware Routing Scenario Parsing

    func testAutoModeApplyScenarioParses() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "auto-mode-apply",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )
        XCTAssertEqual(scenario?.kind, .autoModeApply)
    }

    func testManualModeAdvisoryScenarioParses() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "manual-mode-advisory",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )
        XCTAssertEqual(scenario?.kind, .manualModeAdvisory)
    }

    func testOverrideOrPinScenarioParses() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "override-or-pin",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )
        XCTAssertEqual(scenario?.kind, .overrideOrPin)
    }

    func testStaleOrRefreshScenarioParses() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "stale-or-refresh",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )
        XCTAssertEqual(scenario?.kind, .staleOrRefresh)
    }

    func testFailedReassignmentScenarioParses() {
        let scenario = LiveE2EScenario.resolved(
            from: [
                "ROCKEROOM_LIVE_E2E_SCENARIO": "failed-reassignment",
                "ROCKEROOM_LIVE_E2E_LINK": "https://example.com/live"
            ]
        )
        XCTAssertEqual(scenario?.kind, .failedReassignment)
    }

    func testUnknownDestinationRoutingScenarioDegradesToNil() {
        // An unknown destination-routing scenario name must not corrupt normal startup.
        // The runner degrades to a no-op rather than throwing or crashing.
        XCTAssertNil(
            LiveE2EScenario.resolved(
                from: ["ROCKEROOM_LIVE_E2E_SCENARIO": "auto-mode-apply-v2"]
            )
        )
        XCTAssertNil(
            LiveE2EScenario.resolved(
                from: ["ROCKEROOM_LIVE_E2E_SCENARIO": "broken-scenario"]
            )
        )
    }

    // MARK: - Destination-Aware Routing Scenario Runner Behavior

    func testAutoModeApplyScenarioProducesNoActionsBeforeRuntimeImpl() {
        // Until the routing engine is implemented, autoModeApply degrades to a no-op.
        // This test verifies the contract shape without committing to runtime behavior.
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .autoModeApply, subscriptionLink: "https://example.com/live")
        )

        let state = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .home,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: state, actions: record)
        XCTAssertEqual(actions, [], "autoModeApply should produce no actions until routing engine is implemented")
    }

    func testManualModeAdvisoryScenarioProducesNoActionsBeforeRuntimeImpl() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .manualModeAdvisory, subscriptionLink: "https://example.com/live")
        )

        let state = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .home,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: state, actions: record)
        XCTAssertEqual(actions, [], "manualModeAdvisory should produce no actions until routing engine is implemented")
    }

    func testOverrideOrPinScenarioProducesNoActionsBeforeRuntimeImpl() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .overrideOrPin, subscriptionLink: "https://example.com/live")
        )

        let state = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .home,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: state, actions: record)
        XCTAssertEqual(actions, [], "overrideOrPin should produce no actions until routing engine is implemented")
    }

    func testStaleOrRefreshScenarioProducesNoActionsBeforeRuntimeImpl() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .staleOrRefresh, subscriptionLink: "https://example.com/live")
        )

        let state = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .home,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: state, actions: record)
        XCTAssertEqual(actions, [], "staleOrRefresh should produce no actions until routing engine is implemented")
    }

    func testFailedReassignmentScenarioProducesNoActionsBeforeRuntimeImpl() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .failedReassignment, subscriptionLink: "https://example.com/live")
        )

        let state = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .home,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: state, actions: record)
        XCTAssertEqual(actions, [], "failedReassignment should produce no actions until routing engine is implemented")
    }

    func testPinUnpinScenarioDoesNotReplayPinAfterUnpin() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .pinUnpinHome, subscriptionLink: "https://example.com/live")
        )

        let readyForPin = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .expertConsole,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(state: readyForPin, actions: record)

        let pinned = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .expertConsole,
            refreshHintText: nil,
            pinnedCandidateID: "stable",
            rankedCandidates: readyForPin.rankedCandidates
        )
        runner.advance(state: pinned, actions: record)

        let unpinned = LiveE2ERunner.State(
            hasImportedSubscription: true,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: true,
            isBenchmarkInFlight: false,
            selectedTab: .expertConsole,
            refreshHintText: nil,
            pinnedCandidateID: nil,
            rankedCandidates: readyForPin.rankedCandidates
        )
        runner.advance(state: unpinned, actions: record)

        XCTAssertEqual(
            actions,
            [
                .pinCandidate("stable"),
                .unpinCandidate,
                .selectTab(.home)
            ]
        )
    }
}
