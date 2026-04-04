import Foundation

public protocol PersistentDataStoring: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class UserDefaultsDataStore: PersistentDataStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = UserDefaultsDataStore.makeDefaults()) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data?, forKey key: String) {
        defaults.set(data, forKey: key)
    }

    public static func makeDefaults() -> UserDefaults {
        if let suiteName = ProcessInfo.processInfo.environment["ROCKEROOM_STORAGE_SUITE"],
           let defaults = UserDefaults(suiteName: suiteName) {
            return defaults
        }

        return .standard
    }
}

public final class InMemoryDataStore: PersistentDataStoring, @unchecked Sendable {
    private var values: [String: Data] = [:]

    public init() {}

    public func data(forKey key: String) -> Data? {
        values[key]
    }

    public func set(_ data: Data?, forKey key: String) {
        values[key] = data
    }
}
