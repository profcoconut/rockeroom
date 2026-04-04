import XCTest

@testable import SharedKit

final class PinStateStoreTests: XCTestCase {
    func testStoreRestoresPersistedPinState() async throws {
        let store = InMemoryDataStore()
        let pinStateStore = PinStateStore(store: store)

        try await pinStateStore.update(.pinned(candidateID: "stable"))

        let restored = await pinStateStore.current()

        XCTAssertEqual(restored, .pinned(candidateID: "stable"))
    }

    func testStoreClearsCorruptedPinPayload() async {
        let store = InMemoryDataStore()
        let pinStateStore = PinStateStore(store: store)
        store.set(Data("bad".utf8), forKey: "rockeroom.pin-state")

        let restored = await pinStateStore.current()

        XCTAssertEqual(restored, .none)
        XCTAssertNil(store.data(forKey: "rockeroom.pin-state"))
    }
}
