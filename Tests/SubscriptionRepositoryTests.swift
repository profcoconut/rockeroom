import XCTest

@testable import SharedKit

final class SubscriptionRepositoryTests: XCTestCase {
    func testRepositoryPersistsAndLoadsStoredSubscription() async throws {
        let store = InMemoryDataStore()
        let repository = SubscriptionRepository(store: store)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000),
            subscriptionName: "Primary",
            proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
        )

        try await repository.save(link: "https://example.com/sub", config: config)

        let current = await repository.current()

        XCTAssertEqual(current?.subscriptionLink, "https://example.com/sub")
        XCTAssertEqual(current?.config, config)
    }

    func testRepositoryClearRemovesStoredSubscription() async throws {
        let store = InMemoryDataStore()
        let repository = SubscriptionRepository(store: store)
        try await repository.save(
            link: "https://example.com/sub",
            config: SubscriptionConfig(
                sourceURL: URL(string: "https://example.com/sub")!,
                proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
            )
        )

        await repository.clear()
        let current = await repository.current()

        XCTAssertNil(current)
    }

    func testRepositoryClearsCorruptedStoredPayload() async {
        let store = InMemoryDataStore()
        let repository = SubscriptionRepository(store: store)
        store.set(Data("bad-data".utf8), forKey: "rockeroom.stored-subscription")

        let current = await repository.current()

        XCTAssertNil(current)
        XCTAssertNil(store.data(forKey: "rockeroom.stored-subscription"))
    }
}
