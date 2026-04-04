import Foundation
import XCTest

@testable import SharedKit

final class TunnelSessionStoreTests: XCTestCase {
    func testMarkStartingAndRestoreCurrentSession() async throws {
        let store = InMemoryDataStore()
        let sessionStore = TunnelSessionStore(
            store: store,
            key: "rockeroom.tunnel-session",
            clock: { Date(timeIntervalSince1970: 1_700_000_456) }
        )

        try await sessionStore.markStarting(configurationID: "config-1")
        let restored = await sessionStore.current()

        XCTAssertEqual(restored?.configurationID, "config-1")
        XCTAssertEqual(restored?.requestedState, .startRequested)
        XCTAssertEqual(restored?.runtimeState, .starting)
        XCTAssertEqual(restored?.updatedAt, Date(timeIntervalSince1970: 1_700_000_456))
    }

    func testSyncFailedStatusPersistsFailureMessage() async throws {
        let store = InMemoryDataStore()
        let sessionStore = TunnelSessionStore(store: store, key: "rockeroom.tunnel-session")

        try await sessionStore.sync(
            status: ClashAdapterStatus(state: .failed(message: "Tunnel failed"), lastConfigurationID: "config-2"),
            configurationID: "config-2"
        )

        let restored = await sessionStore.current()
        XCTAssertEqual(restored?.configurationID, "config-2")
        XCTAssertEqual(restored?.requestedState, .startRequested)
        XCTAssertEqual(restored?.runtimeState, .failed(message: "Tunnel failed"))
    }

    func testClearRemovesStoredSession() async throws {
        let store = InMemoryDataStore()
        let sessionStore = TunnelSessionStore(store: store, key: "rockeroom.tunnel-session")

        try await sessionStore.markStopped(configurationID: "config-3")
        await sessionStore.clear()
        let current = await sessionStore.current()

        XCTAssertNil(current)
    }
}
