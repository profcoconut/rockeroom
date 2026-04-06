import XCTest

@testable import RockeRoom
@testable import SharedKit

@MainActor
final class ExpertConsoleViewModelTests: XCTestCase {
    func testRefreshBuildsRouteContextControlAndHistoryFromSelectedAssignment() {
        let viewModel = ExpertConsoleViewModel()
        viewModel.refresh(
            snapshot: nil,
            recommendationState: .idle,
            pinState: .none,
            destinationAssignments: makeAssignmentsForConsoleState(),
            monitoringStatusText: "Foreground monitoring active"
        )

        XCTAssertEqual(viewModel.routeContextSummary?.title, "OpenAI via Stable Relay")
        XCTAssertEqual(viewModel.routeContextRows.map(\.value), ["OpenAI", "Home Wi-Fi", "Stable Relay", "Rule"])
        XCTAssertEqual(viewModel.controlState.badgeText, "Holding")
        XCTAssertEqual(viewModel.controlState.title, "Holding for stronger confidence")
        XCTAssertEqual(
            viewModel.bestAlternative?.detailText,
            "Fast Relay looks promising, but RockeRoom is waiting for stronger confidence."
        )
        XCTAssertEqual(viewModel.routeChangeHistoryRows.first?.title, "OpenAI holding on Stable Relay")
        XCTAssertTrue(viewModel.routeChangeHistoryRows.first?.isCurrent == true)
    }

    func testPinnedStateWinsControlCopyAndDestinationPresentation() {
        let viewModel = ExpertConsoleViewModel()
        let assignments = makeAssignmentsForConsoleState()

        viewModel.refresh(
            snapshot: nil,
            recommendationState: .idle,
            pinState: .pinned(candidateID: "stable"),
            destinationAssignments: assignments,
            monitoringStatusText: "Foreground monitoring active"
        )

        XCTAssertEqual(viewModel.controlState.badgeText, "Manual")
        XCTAssertEqual(viewModel.controlState.title, "Pinned route active")
        XCTAssertEqual(
            viewModel.bestAlternative?.detailText,
            "Fast Relay remains visible, but manual control keeps Stable Relay active."
        )
        XCTAssertEqual(viewModel.destinationRows.first?.statusText, "Pinned")
        XCTAssertTrue(viewModel.destinationRows.first?.isPinned == true)
        XCTAssertEqual(viewModel.routeChangeHistoryRows.first?.badgeText, "Manual")
    }

    func testEmptyAssignmentsProduceInspectorAndHistoryEmptyStates() {
        let viewModel = ExpertConsoleViewModel()
        viewModel.refresh(
            snapshot: nil,
            recommendationState: .idle,
            pinState: .none,
            destinationAssignments: nil,
            monitoringStatusText: "Monitoring inactive"
        )

        XCTAssertNil(viewModel.routeContextSummary)
        XCTAssertTrue(viewModel.routeContextRows.isEmpty)
        XCTAssertEqual(viewModel.controlState.badgeText, "Idle")
        XCTAssertTrue(viewModel.routeChangeHistoryRows.isEmpty)
        XCTAssertEqual(
            viewModel.routeChangeHistoryEmptyText,
            "No recent route changes yet. Run Benchmark to seed current routing context and history."
        )
    }

    private func makeAssignmentsForConsoleState() -> DestinationRoutingAssignments {
        var assignments = DestinationRoutingAssignments(
            sourceURL: "https://example.com/sub",
            selectedDestinationID: "openai"
        )

        assignments.insert(
            DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "stable",
                    strategy: .rule
                ),
                mode: .auto,
                assignedProviderLabel: "Stable Relay",
                source: .automaticSelection,
                assignedAt: 2_000,
                freshness: 0.92,
                status: .holding,
                measuredLatencyMS: 42,
                failureRate: 0.2,
                stabilityScore: 0.91,
                recentChangeSummary: "Holding OpenAI on Stable Relay until route confidence is stronger.",
                alternativeProviderID: "fast",
                alternativeProviderLabel: "Fast Relay"
            )
        )

        assignments.insert(
            DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "netflix",
                    providerID: "fast",
                    strategy: .direct
                ),
                mode: .auto,
                assignedProviderLabel: "Fast Relay",
                source: .automaticSelection,
                assignedAt: 1_500,
                freshness: 0.95,
                status: .switched,
                measuredLatencyMS: 36,
                failureRate: 0.1,
                stabilityScore: 0.94,
                recentChangeSummary: "Switched Netflix to Fast Relay because the measured gain is now clearly meaningful.",
                alternativeProviderID: "stable",
                alternativeProviderLabel: "Stable Relay"
            )
        )

        return assignments
    }
}
