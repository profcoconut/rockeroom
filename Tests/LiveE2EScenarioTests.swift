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
