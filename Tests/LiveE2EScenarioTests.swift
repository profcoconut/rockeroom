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
            LiveE2EScenario(kind: .expertConsole, subscriptionLink: "https://example.com/live", destinationAssignment: nil)
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

    func testAutoModeApplyScenarioReplaysCurrentRecommendedHomeState() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .autoModeApply, subscriptionLink: "https://example.com/live")
        )

        XCTAssertEqual(
            runner.nextAction(
                for: makeState(
                    hasImportedSubscription: true,
                    hasBenchmarkResults: true,
                    selectedTab: .expertConsole
                )
            ),
            .selectTab(.home)
        )
    }

    func testManualModeAdvisoryScenarioOpensExpertConsoleForInspection() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .manualModeAdvisory, subscriptionLink: "https://example.com/live")
        )

        XCTAssertEqual(
            runner.nextAction(
                for: makeState(
                    hasImportedSubscription: true,
                    hasBenchmarkResults: true,
                    selectedTab: .home
                )
            ),
            .selectTab(.expertConsole)
        )
    }

    func testOverrideOrPinScenarioPinsStableCandidateThenReturnsHome() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .overrideOrPin, subscriptionLink: "https://example.com/live")
        )

        var actions: [LiveE2ERunner.Action] = []
        let record = LiveE2ERunner.Actions(
            importSubscription: { actions.append(.importSubscription($0)) },
            runBenchmark: { actions.append(.runBenchmark) },
            selectTab: { actions.append(.selectTab($0)) },
            pinCandidate: { actions.append(.pinCandidate($0)) },
            unpinCandidate: { actions.append(.unpinCandidate) }
        )

        runner.advance(
            state: makeState(
                hasImportedSubscription: true,
                hasBenchmarkResults: true,
                selectedTab: .expertConsole
            ),
            actions: record
        )
        runner.advance(
            state: makeState(
                hasImportedSubscription: true,
                hasBenchmarkResults: true,
                selectedTab: .expertConsole,
                pinnedCandidateID: "stable"
            ),
            actions: record
        )

        XCTAssertEqual(actions, [.pinCandidate("stable"), .selectTab(.home)])
    }

    func testStaleOrRefreshScenarioReplaysTheStaleHintContract() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .staleOrRefresh, subscriptionLink: "https://example.com/live")
        )

        XCTAssertEqual(
            runner.nextAction(
                for: makeState(
                    hasImportedSubscription: true,
                    hasBenchmarkResults: true,
                    selectedTab: .expertConsole
                )
            ),
            .selectTab(.home)
        )
    }

    func testFailedReassignmentScenarioReusesRecoverableFailureFlow() {
        let runner = LiveE2ERunner(
            scenario: LiveE2EScenario(kind: .failedReassignment, subscriptionLink: "https://example.com/live")
        )

        XCTAssertEqual(
            runner.nextAction(
                for: makeState(
                    hasImportedSubscription: true,
                    hasBenchmarkResults: false,
                    selectedTab: .home
                )
            ),
            .runBenchmark
        )
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

    private func makeState(
        hasImportedSubscription: Bool,
        hasBenchmarkResults: Bool,
        selectedTab: MainTab,
        pinnedCandidateID: String? = nil
    ) -> LiveE2ERunner.State {
        LiveE2ERunner.State(
            hasImportedSubscription: hasImportedSubscription,
            importErrorMessage: nil,
            isImporting: false,
            hasBenchmarkResults: hasBenchmarkResults,
            isBenchmarkInFlight: false,
            selectedTab: selectedTab,
            refreshHintText: nil,
            pinnedCandidateID: pinnedCandidateID,
            rankedCandidates: [
                .init(candidateID: "fast", title: "Fast Relay"),
                .init(candidateID: "stable", title: "Stable Relay")
            ]
        )
    }
}
