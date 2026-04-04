import Foundation

public actor SubscriptionRepository {
    private let store: any PersistentDataStoring
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        store: any PersistentDataStoring = UserDefaultsDataStore(),
        key: String = "rockeroom.stored-subscription"
    ) {
        self.store = store
        self.key = key
    }

    public func save(link: String, config: SubscriptionConfig) throws {
        let subscription = StoredSubscription(subscriptionLink: link, config: config)
        let data = try encoder.encode(subscription)
        store.set(data, forKey: key)
    }

    public func current() -> StoredSubscription? {
        guard let data = store.data(forKey: key) else { return nil }

        do {
            return try decoder.decode(StoredSubscription.self, from: data)
        } catch {
            store.set(nil, forKey: key)
            return nil
        }
    }

    public func clear() {
        store.set(nil, forKey: key)
    }
}
