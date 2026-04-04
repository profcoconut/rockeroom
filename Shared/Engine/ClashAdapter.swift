import Foundation
import NetworkExtension

public struct ClashAdapterStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case stopped
        case starting
        case running
        case failed(message: String)
    }

    public var state: State
    public var lastConfigurationID: String?

    public init(state: State = .stopped, lastConfigurationID: String? = nil) {
        self.state = state
        self.lastConfigurationID = lastConfigurationID
    }
}

public protocol ClashControlling: Sendable {
    func start(with configuration: SubscriptionConfig) async throws
    func stop() async
    func status() async -> ClashAdapterStatus
}

public protocol ClashEngine: Sendable {
    func start(with configuration: SubscriptionConfig) async throws
    func stop() async
    func status() async -> ClashAdapterStatus
}

public protocol TunnelManaging: Sendable {
    func startTunnel(configData: Data, configurationID: String) async throws
    func stopTunnel() async
    func status() async -> ClashAdapterStatus
}

public final class ClashAdapter: ClashControlling, Sendable {
    private let engine: any ClashEngine

    public init(engine: any ClashEngine) {
        self.engine = engine
    }

    public convenience init(sessionStore: TunnelSessionStore = TunnelSessionStore()) {
        self.init(engine: TunnelManagerClashEngine(sessionStore: sessionStore))
    }

    public func start(with configuration: SubscriptionConfig) async throws {
        try await engine.start(with: configuration)
    }

    public func stop() async {
        await engine.stop()
    }

    public func status() async -> ClashAdapterStatus {
        await engine.status()
    }
}

public actor TunnelManagerClashEngine: ClashEngine {
    private let tunnelManager: any TunnelManaging
    private let sessionStore: TunnelSessionStore
    private let encoder = JSONEncoder()

    public init(
        tunnelManager: any TunnelManaging = SystemTunnelManager(),
        sessionStore: TunnelSessionStore = TunnelSessionStore()
    ) {
        self.tunnelManager = tunnelManager
        self.sessionStore = sessionStore
    }

    public func start(with configuration: SubscriptionConfig) async throws {
        try await sessionStore.markStarting(configurationID: configuration.configurationID)

        do {
            let configData = try encoder.encode(configuration)
            try await tunnelManager.startTunnel(
                configData: configData,
                configurationID: configuration.configurationID
            )
            let currentStatus = await tunnelManager.status()
            try await sessionStore.sync(status: currentStatus, configurationID: configuration.configurationID)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let failedStatus = ClashAdapterStatus(
                state: .failed(message: message),
                lastConfigurationID: configuration.configurationID
            )
            try? await sessionStore.sync(status: failedStatus, configurationID: configuration.configurationID)
            throw error
        }
    }

    public func stop() async {
        await tunnelManager.stopTunnel()
        let currentStatus = await tunnelManager.status()
        try? await sessionStore.sync(status: currentStatus, configurationID: currentStatus.lastConfigurationID)
    }

    public func status() async -> ClashAdapterStatus {
        let currentStatus = await tunnelManager.status()
        try? await sessionStore.sync(status: currentStatus, configurationID: currentStatus.lastConfigurationID)
        return currentStatus
    }
}

public actor ProviderRuntimeClashEngine: ClashEngine {
    private var currentStatus = ClashAdapterStatus()

    public init() {}

    public func start(with configuration: SubscriptionConfig) async throws {
        currentStatus = ClashAdapterStatus(
            state: .running,
            lastConfigurationID: configuration.configurationID
        )
    }

    public func stop() async {
        currentStatus = ClashAdapterStatus(
            state: .stopped,
            lastConfigurationID: currentStatus.lastConfigurationID
        )
    }

    public func status() async -> ClashAdapterStatus {
        currentStatus
    }
}

public actor InMemoryTunnelManager: TunnelManaging {
    private var currentStatus = ClashAdapterStatus()

    public init() {}

    public func startTunnel(configData: Data, configurationID: String) async throws {
        currentStatus = ClashAdapterStatus(
            state: .running,
            lastConfigurationID: configurationID
        )
    }

    public func stopTunnel() async {
        currentStatus = ClashAdapterStatus(
            state: .stopped,
            lastConfigurationID: currentStatus.lastConfigurationID
        )
    }

    public func status() async -> ClashAdapterStatus {
        currentStatus
    }
}

public final class SystemTunnelManager: TunnelManaging, @unchecked Sendable {
    private let providerBundleIdentifier: String
    private let localizedDescription: String
    private var manager: NETunnelProviderManager?

    public init(
        providerBundleIdentifier: String = "com.profcoconut.rockeroom.PacketTunnelExtension",
        localizedDescription: String = "RockeRoom"
    ) {
        self.providerBundleIdentifier = providerBundleIdentifier
        self.localizedDescription = localizedDescription
    }

    public func startTunnel(configData: Data, configurationID: String) async throws {
        let manager = currentManager()
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = providerBundleIdentifier
        protocolConfiguration.serverAddress = "RockeRoom"
        protocolConfiguration.providerConfiguration = [
            "subscriptionConfig": configData
        ]

        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = localizedDescription
        manager.isEnabled = true

        try await save(manager)
        try await load(manager)

        guard let session = manager.connection as? NETunnelProviderSession else {
            throw TunnelManagerError.invalidSession
        }

        do {
            try session.startVPNTunnel()
        } catch {
            throw TunnelManagerError.startFailed(message: error.localizedDescription)
        }
    }

    public func stopTunnel() async {
        guard let manager else { return }
        manager.connection.stopVPNTunnel()
    }

    public func status() async -> ClashAdapterStatus {
        guard let manager else {
            return ClashAdapterStatus(state: .stopped)
        }

        return ClashAdapterStatus(
            state: map(manager.connection.status),
            lastConfigurationID: currentConfigurationID(from: manager)
        )
    }

    private func currentManager() -> NETunnelProviderManager {
        if let manager {
            return manager
        }

        let manager = NETunnelProviderManager()
        self.manager = manager
        return manager
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func load(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func currentConfigurationID(from manager: NETunnelProviderManager) -> String? {
        guard
            let protocolConfiguration = manager.protocolConfiguration as? NETunnelProviderProtocol,
            let data = protocolConfiguration.providerConfiguration?["subscriptionConfig"] as? Data,
            let config = try? JSONDecoder().decode(SubscriptionConfig.self, from: data)
        else {
            return nil
        }

        return config.configurationID
    }

    private func map(_ status: NEVPNStatus) -> ClashAdapterStatus.State {
        switch status {
        case .connected:
            return .running
        case .connecting, .reasserting:
            return .starting
        case .disconnecting, .disconnected, .invalid:
            return .stopped
        @unknown default:
            return .failed(message: "Unknown tunnel status.")
        }
    }
}

public enum TunnelManagerError: LocalizedError {
    case invalidSession
    case startFailed(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidSession:
            return "Tunnel session is unavailable."
        case .startFailed(let message):
            return message
        }
    }
}
