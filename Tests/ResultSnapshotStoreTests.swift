import XCTest

@testable import SharedKit

final class ResultSnapshotStoreTests: XCTestCase {
    func testStoreReturnsMostRecentSnapshot() async {
        let store = ResultSnapshotStore(store: InMemoryDataStore())
        let first = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/a")!,
            candidates: [],
            overallConfidence: 0.1,
            freshness: 0.2,
            isPartial: true
        )
        let second = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/b")!,
            candidates: [],
            overallConfidence: 0.9,
            freshness: 1.0,
            isPartial: false
        )

        await store.update(first)
        await store.update(second)

        let current = await store.current()

        XCTAssertEqual(current?.sourceURL, second.sourceURL)
        XCTAssertEqual(current?.overallConfidence, 0.9)
        XCTAssertEqual(current?.freshness, 1.0)
    }

    func testStoreRestoresSnapshotFromPersistentStore() async throws {
        let dataStore = InMemoryDataStore()
        let store = ResultSnapshotStore(store: dataStore)
        let snapshot = ResultSnapshot(
            sourceURL: URL(string: "https://example.com/restored")!,
            candidates: [
                ProbeCandidateResult(
                    candidateID: "fast",
                    label: "Fast Relay",
                    metrics: [ProbeMetric(name: "latency", value: 120, unit: "ms", betterIsHigher: false)],
                    score: 0.9,
                    confidence: 0.86,
                    freshness: 0.92
                )
            ],
            overallConfidence: 0.86,
            freshness: 0.92,
            isPartial: false
        )

        await store.update(snapshot)

        let restoredStore = ResultSnapshotStore(store: dataStore)
        let restored = await restoredStore.current()

        XCTAssertEqual(restored, snapshot)
    }

    func testStoreClearsCorruptedSnapshotPayload() async {
        let dataStore = InMemoryDataStore()
        dataStore.set(Data("bad-snapshot".utf8), forKey: "rockeroom.result-snapshot")
        let store = ResultSnapshotStore(store: dataStore)

        let restored = await store.current()

        XCTAssertNil(restored)
        XCTAssertNil(dataStore.data(forKey: "rockeroom.result-snapshot"))
    }
}
