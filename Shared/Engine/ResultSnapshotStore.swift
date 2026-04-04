import Foundation

public actor ResultSnapshotStore {
    private let store: any PersistentDataStoring
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var latestSnapshot: ResultSnapshot?

    public init(
        store: any PersistentDataStoring = UserDefaultsDataStore(),
        key: String = "rockeroom.result-snapshot"
    ) {
        self.store = store
        self.key = key
    }

    public func update(_ snapshot: ResultSnapshot) {
        latestSnapshot = snapshot
        if let data = try? encoder.encode(snapshot) {
            store.set(data, forKey: key)
        }
    }

    public func current() -> ResultSnapshot? {
        if let latestSnapshot {
            return latestSnapshot
        }

        guard let data = store.data(forKey: key) else { return nil }

        do {
            let snapshot = try decoder.decode(ResultSnapshot.self, from: data)
            latestSnapshot = snapshot
            return snapshot
        } catch {
            store.set(nil, forKey: key)
            latestSnapshot = nil
            return nil
        }
    }

    public func clear() {
        latestSnapshot = nil
        store.set(nil, forKey: key)
    }
}
