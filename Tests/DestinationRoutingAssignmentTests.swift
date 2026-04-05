import XCTest
@testable import SharedKit

/// Characterization tests for production destination routing assignment types.
///
/// These tests verify that `DestinationRoutingAssignment` and `DestinationRoutingAssignments`
/// can express all semantics required by the Sprint 2 assignment model before the store
/// and view-model integration exist.
@MainActor
final class DestinationRoutingAssignmentTests: XCTestCase {

    // MARK: - RoutingMode

    func testRoutingModeHasAutoAndManualCases() {
        XCTAssertEqual(RoutingMode.auto, .auto)
        XCTAssertEqual(RoutingMode.manual, .manual)
    }

    func testRoutingModeIsCodable() throws {
        let data = try JSONEncoder().encode(RoutingMode.auto)
        let decoded = try JSONDecoder().decode(RoutingMode.self, from: data)
        XCTAssertEqual(decoded, .auto)
    }

    func testRoutingModeRawValuesAreStable() {
        XCTAssertEqual(RoutingMode.auto.rawValue, "auto")
        XCTAssertEqual(RoutingMode.manual.rawValue, "manual")
    }

    // MARK: - DestinationRoutingAssignment

    func testAssignmentExposesDestinationProviderAndMode() {
        let assignment = DestinationRoutingAssignment(
            destinationID: "openai",
            mode: .auto,
            assignedProviderID: "hk-01",
            assignedProviderLabel: "Hong Kong 01",
            strategyName: "rule",
            source: .automaticSelection,
            assignedAt: 1000
        )

        XCTAssertEqual(assignment.destinationID, "openai")
        XCTAssertEqual(assignment.mode, .auto)
        XCTAssertEqual(assignment.assignedProviderID, "hk-01")
        XCTAssertEqual(assignment.assignedProviderLabel, "Hong Kong 01")
        XCTAssertEqual(assignment.strategyName, "rule")
        XCTAssertEqual(assignment.source, .automaticSelection)
    }

    func testManualOverrideAssignmentIsDistinguishableFromAuto() {
        let auto = DestinationRoutingAssignment(
            destinationID: "netflix",
            mode: .auto,
            assignedProviderID: "jp-01",
            assignedProviderLabel: "Japan 01",
            strategyName: "rule",
            source: .automaticSelection,
            assignedAt: 1000
        )

        let manual = DestinationRoutingAssignment(
            destinationID: "netflix",
            mode: .manual,
            assignedProviderID: "us-01",
            assignedProviderLabel: "US 01",
            strategyName: "rule",
            source: .manualOverride,
            assignedAt: 1000
        )

        XCTAssertEqual(auto.mode, .auto)
        XCTAssertEqual(auto.source, .automaticSelection)
        XCTAssertEqual(manual.mode, .manual)
        XCTAssertEqual(manual.source, .manualOverride)
        XCTAssertNotEqual(auto.assignedProviderID, manual.assignedProviderID)
    }

    func testAssignmentWithNoEvidenceMetadataDecodesSafely() throws {
        // Minimal JSON missing evidenceLinkSnapshotID and freshness
        let json = """
        {
            "destinationID": "openai",
            "mode": "manual",
            "assignedProviderID": "hk-01",
            "assignedProviderLabel": "Hong Kong 01",
            "strategyName": "rule",
            "source": "manualOverride",
            "assignedAt": 1000
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DestinationRoutingAssignment.self, from: json)

        XCTAssertEqual(decoded.destinationID, "openai")
        XCTAssertEqual(decoded.mode, .manual)
        XCTAssertEqual(decoded.assignedProviderID, "hk-01")
        XCTAssertNil(decoded.evidenceLinkSnapshotID)
        XCTAssertNil(decoded.freshness)
    }

    func testMalformedAssignmentFailsDecoding() {
        // Missing required field "destinationID"
        let json = """
        {
            "mode": "manual",
            "assignedProviderID": "hk-01",
            "assignedProviderLabel": "Hong Kong 01",
            "strategyName": "rule",
            "source": "manualOverride",
            "assignedAt": 1000
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            _ = try JSONDecoder().decode(DestinationRoutingAssignment.self, from: json)
        )
    }

    func testAssignmentRoundTripsThroughJSON() throws {
        let original = DestinationRoutingAssignment(
            destinationID: "claude",
            mode: .auto,
            assignedProviderID: "sg-01",
            assignedProviderLabel: "Singapore 01",
            strategyName: "rule",
            source: .automaticSelection,
            assignedAt: 2000,
            evidenceLinkSnapshotID: "snap-001",
            freshness: 0.92
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DestinationRoutingAssignment.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testFinalDestinationAssignmentHasStableIdentity() {
        // The Final destination is the fallback. It should have a stable ID
        // and be usable like any other destination.
        let assignment = DestinationRoutingAssignment(
            destinationID: "final",
            mode: .auto,
            assignedProviderID: "any",
            assignedProviderLabel: "Anycast",
            strategyName: "direct",
            source: .automaticSelection,
            assignedAt: 500
        )

        XCTAssertEqual(assignment.destinationID, "final")
        XCTAssertEqual(assignment.mode, .auto)
        XCTAssertEqual(assignment.assignedProviderID, "any")
    }

    // MARK: - DestinationRoutingAssignments (container)

    func testAssignmentsContainerStoresMultipleDestinations() {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .manual,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1000
            )
        )

        XCTAssertEqual(container.count, 2)
        XCTAssertEqual(container["openai"]?.mode, .auto)
        XCTAssertEqual(container["netflix"]?.mode, .manual)
    }

    func testUpdatingOneAssignmentDoesNotDropOthers() {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .manual,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1000
            )
        )

        // Update only the openai assignment
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "sg-02",
                assignedProviderLabel: "Singapore 02",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 2000
            )
        )

        XCTAssertEqual(container.count, 2)
        XCTAssertEqual(container["openai"]?.assignedProviderID, "sg-02")
        XCTAssertEqual(container["netflix"]?.assignedProviderID, "jp-01")
    }

    func testAssignmentsContainerClears() {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )

        container.clear()

        XCTAssertTrue(container.isEmpty)
    }

    func testAssignmentsContainerRoundTripsThroughJSON() throws {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "claude",
                mode: .manual,
                assignedProviderID: "us-01",
                assignedProviderLabel: "US 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1500,
                evidenceLinkSnapshotID: "snap-001",
                freshness: 0.88
            )
        )

        let data = try JSONEncoder().encode(container)
        let decoded = try JSONDecoder().decode(DestinationRoutingAssignments.self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded["openai"]?.mode, .auto)
        XCTAssertEqual(decoded["claude"]?.mode, .manual)
        XCTAssertEqual(decoded["claude"]?.freshness, 0.88)
    }

    func testCorruptedAssignmentsPayloadDecodesToEmptyOrNil() throws {
        let corruptedData = Data("not valid json".utf8)

        let decoded = try? JSONDecoder().decode(DestinationRoutingAssignments.self, from: corruptedData)
        // If decoding fails entirely, the store will handle corruption-clearing.
        // If it partially decodes, the container should not expose corrupted state.
        if decoded != nil {
            XCTAssertTrue(decoded?.isEmpty ?? true)
        }
    }

    // MARK: - Selected Assignment

    func testSelectedAssignmentTracksCurrentActiveDestination() {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .auto,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 500
            )
        )
        container.selectedDestinationID = "netflix"

        XCTAssertEqual(container.selectedDestinationID, "netflix")
        XCTAssertEqual(container.selectedAssignment?.destinationID, "netflix")
    }

    func testSelectedAssignmentIsNilWhenNoDestinationSelected() {
        let container = DestinationRoutingAssignments()
        XCTAssertNil(container.selectedAssignment)
    }

    func testSelectedAssignmentRoundTrips() throws {
        var container = DestinationRoutingAssignments()
        container.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        container.selectedDestinationID = "openai"

        let data = try JSONEncoder().encode(container)
        let decoded = try JSONDecoder().decode(DestinationRoutingAssignments.self, from: data)

        XCTAssertEqual(decoded.selectedDestinationID, "openai")
    }
}
