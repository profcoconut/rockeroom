import Foundation

/// Actor-backed store for persisting and restoring destination routing assignments.
///
/// This store follows the same pattern as `SubscriptionRepository`, `ResultSnapshotStore`,
/// and `PinStateStore`:
/// - Actor-backed for thread safety
/// - Wraps a `PersistentDataStoring` (UserDefaults or in-memory)
/// - JSON codable payload
/// - Corruption-clearing: if decode fails, the payload is cleared and restore returns nil
///
/// Storage key: `"rockeroom.destination-routing-assignments"`
public actor DestinationRoutingAssignmentStore {
    private let store: any PersistentDataStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The storage key used for the assignments payload.
    public static let storageKey = "rockeroom.destination-routing-assignments"

    /// Creates a store with the given backing persistence layer.
    public init(store: any PersistentDataStoring = UserDefaultsDataStore()) {
        self.store = store
    }

    /// Saves the given assignments to persistent storage.
    public func save(_ assignments: DestinationRoutingAssignments) {
        guard let data = try? encoder.encode(assignments) else { return }
        store.set(data, forKey: Self.storageKey)
    }

    /// Restores the current assignments from persistent storage.
    ///
    /// Returns nil if no payload exists.
    /// Returns nil and clears corrupted payloads if decode fails.
    public func current() -> DestinationRoutingAssignments? {
        guard let data = store.data(forKey: Self.storageKey) else { return nil }

        do {
            return try decoder.decode(DestinationRoutingAssignments.self, from: data)
        } catch {
            // Corruption-clearing: if the payload is corrupted, clear it
            // so subsequent restores don't repeatedly encounter the same bad data.
            store.set(nil, forKey: Self.storageKey)
            return nil
        }
    }

    /// Clears all persisted destination routing assignments.
    public func clear() {
        store.set(nil, forKey: Self.storageKey)
    }
}
