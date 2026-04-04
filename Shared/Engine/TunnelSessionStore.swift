import Foundation

public actor TunnelSessionStore {
    private let store: any PersistentDataStoring
    private let key: String
    private let clock: @Sendable () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        store: any PersistentDataStoring = UserDefaultsDataStore(),
        key: String = "rockeroom.tunnel-session",
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.key = key
        self.clock = clock
    }

    public func current() -> TunnelSession? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? decoder.decode(TunnelSession.self, from: data)
    }

    public func update(_ session: TunnelSession) throws {
        let data = try encoder.encode(session)
        store.set(data, forKey: key)
    }

    public func markStarting(configurationID: String) throws {
        try update(
            TunnelSession(
                configurationID: configurationID,
                requestedState: .startRequested,
                runtimeState: .starting,
                updatedAt: clock()
            )
        )
    }

    public func markStopped(configurationID: String?) throws {
        try update(
            TunnelSession(
                configurationID: configurationID,
                requestedState: .stopRequested,
                runtimeState: .stopped,
                updatedAt: clock()
            )
        )
    }

    public func sync(status: ClashAdapterStatus, configurationID: String?) throws {
        let runtimeState: TunnelSession.RuntimeState

        switch status.state {
        case .stopped:
            runtimeState = .stopped
        case .starting:
            runtimeState = .starting
        case .running:
            runtimeState = .running
        case .failed(let message):
            runtimeState = .failed(message: message)
        }

        try update(
            TunnelSession(
                configurationID: configurationID ?? status.lastConfigurationID,
                requestedState: runtimeState == .stopped ? .stopRequested : .startRequested,
                runtimeState: runtimeState,
                updatedAt: clock()
            )
        )
    }

    public func clear() {
        store.set(nil, forKey: key)
    }
}
