import Foundation

public actor PinStateStore {
    private let store: any PersistentDataStoring
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        store: any PersistentDataStoring = UserDefaultsDataStore(),
        key: String = "rockeroom.pin-state"
    ) {
        self.store = store
        self.key = key
    }

    public func current() -> PinState {
        guard let data = store.data(forKey: key) else { return .none }

        do {
            return try decoder.decode(PinState.self, from: data)
        } catch {
            store.set(nil, forKey: key)
            return .none
        }
    }

    public func update(_ pinState: PinState) throws {
        let data = try encoder.encode(pinState)
        store.set(data, forKey: key)
    }

    public func clear() {
        store.set(nil, forKey: key)
    }
}
