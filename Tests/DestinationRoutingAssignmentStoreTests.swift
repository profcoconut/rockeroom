import XCTest
@testable import SharedKit

/// Tests for DestinationRoutingAssignmentStore persistence behavior.
///
/// The store follows the same actor + PersistentDataStoring + corruption-clearing
/// pattern as SubscriptionRepository, ResultSnapshotStore, and PinStateStore.
@MainActor
final class DestinationRoutingAssignmentStoreTests: XCTestCase {

    // MARK: - Happy Path

    func testStoreRestoresPersistedAssignmentPayload() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments()
        assignments.insert(
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
        assignments.selectedDestinationID = "openai"

        await store.save(assignments)

        let restored = await store.current()
        XCTAssertEqual(restored?.count, 1)
        XCTAssertEqual(restored?.selectedDestinationID, "openai")
        XCTAssertEqual(restored?["openai"]?.mode, .auto)
        XCTAssertEqual(restored?["openai"]?.routeContext.environment, .unknown)
        XCTAssertEqual(restored?["openai"]?.routeContext.strategy, .rule)
    }

    func testStoreRoundTripsRouteContextAwareAssignmentWithEnvironmentAndStrategy() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments(sourceURL: "https://example.com/sub", selectedDestinationID: "openai")
        assignments.insert(
            DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "hk-01",
                    strategy: .fallbackProxy
                ),
                mode: .auto,
                assignedProviderLabel: "Hong Kong 01",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )

        await store.save(assignments)

        let restored = await store.current()
        XCTAssertEqual(restored?.selectedDestinationID, "openai")
        XCTAssertEqual(restored?["openai"]?.routeContext.environment, .wifiHome)
        XCTAssertEqual(restored?["openai"]?.routeContext.strategy, .fallbackProxy)
    }

    func testStorePreservesExplicitHoldAndSwitchReasons() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments(sourceURL: "https://example.com/sub", selectedDestinationID: "openai")
        assignments.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000,
                freshness: 0.9,
                status: .holding,
                holdReason: .staleEvidence,
                recentChangeSummary: "Holding OpenAI on Hong Kong 01 because the evidence is getting stale."
            )
        )

        await store.save(assignments)

        let restored = await store.current()
        XCTAssertEqual(restored?["openai"]?.status, .holding)
        XCTAssertEqual(restored?["openai"]?.holdReason, .staleEvidence)
        XCTAssertNil(restored?["openai"]?.switchReason)
    }

    func testStorePersistsMultipleAssignments() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments()
        assignments.insert(
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
        assignments.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .manual,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1500
            )
        )
        assignments.selectedDestinationID = "netflix"

        await store.save(assignments)

        let restored = await store.current()
        XCTAssertEqual(restored?.count, 2)
        XCTAssertEqual(restored?.selectedDestinationID, "netflix")
        XCTAssertEqual(restored?["openai"]?.mode, .auto)
        XCTAssertEqual(restored?["netflix"]?.mode, .manual)
    }

    // MARK: - Update Semantics

    func testUpdatingOneAssignmentDoesNotDropOthers() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var initial = DestinationRoutingAssignments()
        initial.insert(
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
        await store.save(initial)

        var updated = DestinationRoutingAssignments()
        updated.insert(
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
        updated.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .manual,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1500
            )
        )
        await store.save(updated)

        let restored = await store.current()
        XCTAssertEqual(restored?.count, 2)
        XCTAssertEqual(restored?["openai"]?.assignedProviderID, "sg-02")
        XCTAssertEqual(restored?["netflix"]?.assignedProviderID, "jp-01")
    }

    // MARK: - Clear

    func testClearRemovesAllAssignments() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments()
        assignments.insert(
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
        await store.save(assignments)
        await store.clear()

        let restored = await store.current()
        XCTAssertNil(restored)
    }

    // MARK: - Corruption Handling

    func testCorruptedPayloadIsClearedAndRestoreReturnsNil() async {
        let backingStore = InMemoryDataStore()
        // Pre-load corrupted data directly into the backing store
        backingStore.set(Data("corrupted json".utf8), forKey: DestinationRoutingAssignmentStore.storageKey)

        let store = DestinationRoutingAssignmentStore(store: backingStore)

        let restored = await store.current()

        // Store should clear corrupted data and return nil
        XCTAssertNil(restored)
        // Verify the corrupted entry was actually cleared
        let remaining = backingStore.data(forKey: DestinationRoutingAssignmentStore.storageKey)
        XCTAssertNil(remaining)
    }

    func testPartiallyCorruptedPayloadIsClearedAndRestoreReturnsNil() async {
        let backingStore = InMemoryDataStore()
        // Valid JSON that decodes to the wrong type (a single string, not DestinationRoutingAssignments)
        backingStore.set(Data(#""just a string""#.utf8), forKey: DestinationRoutingAssignmentStore.storageKey)

        let store = DestinationRoutingAssignmentStore(store: backingStore)

        let restored = await store.current()
        XCTAssertNil(restored)
    }

    func testLegacyPayloadWithoutRouteContextRestoresWithSafeDefaults() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)
        backingStore.set(
            Data(
                """
                {
                  "sourceURL": "https://example.com/sub",
                  "selectedDestinationID": "openai",
                  "byDestinationID": {
                    "openai": {
                      "destinationID": "openai",
                      "mode": "auto",
                      "assignedProviderID": "hk-01",
                      "assignedProviderLabel": "Hong Kong 01",
                      "strategyName": "rule",
                      "source": "automaticSelection",
                      "assignedAt": 1000
                    }
                  }
                }
                """.utf8
            ),
            forKey: DestinationRoutingAssignmentStore.storageKey
        )

        let restored = await store.current()

        XCTAssertEqual(restored?.selectedDestinationID, "openai")
        XCTAssertEqual(restored?["openai"]?.routeContext.environment, .unknown)
        XCTAssertEqual(restored?["openai"]?.routeContext.strategy, .rule)
        XCTAssertEqual(restored?["openai"]?.assignedProviderID, "hk-01")
    }

    // MARK: - Nil State

    func testCurrentReturnsNilWhenNoPayloadExists() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)
        let restored = await store.current()
        XCTAssertNil(restored)
    }

    // MARK: - SourceURL Preservation

    func testStorePreservesSourceURL() async {
        let backingStore = InMemoryDataStore()
        let store = DestinationRoutingAssignmentStore(store: backingStore)

        var assignments = DestinationRoutingAssignments()
        assignments.sourceURL = "https://example.com/sub"
        assignments.insert(
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

        await store.save(assignments)

        let restored = await store.current()
        XCTAssertEqual(restored?.sourceURL, "https://example.com/sub")
    }
}
