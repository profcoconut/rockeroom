import Foundation
import XCTest

@testable import SharedKit

final class ClashAdapterTests: XCTestCase {
    func testStartWithInMemoryTunnelManagerTransitionsToRunning() async throws {
        let sessionStore = TunnelSessionStore(store: InMemoryDataStore(), key: "rockeroom.tunnel-session")
        let tunnelManager = InMemoryTunnelManager()
        let adapter = ClashAdapter(
            engine: TunnelManagerClashEngine(
                tunnelManager: tunnelManager,
                sessionStore: sessionStore
            )
        )
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/subscription")!,
            proxies: [ClashProxy(name: "Fast Relay", type: "ss", server: "1.1.1.1", port: 8388)]
        )

        try await adapter.start(with: config)

        let status = await adapter.status()
        let session = await sessionStore.current()
        XCTAssertEqual(status, ClashAdapterStatus(state: .running, lastConfigurationID: config.configurationID))
        XCTAssertEqual(session?.configurationID, config.configurationID)
        XCTAssertEqual(session?.runtimeState, .running)
    }

    func testStopTransitionsPersistedSessionToStopped() async throws {
        let sessionStore = TunnelSessionStore(store: InMemoryDataStore(), key: "rockeroom.tunnel-session")
        let tunnelManager = InMemoryTunnelManager()
        let adapter = ClashAdapter(
            engine: TunnelManagerClashEngine(
                tunnelManager: tunnelManager,
                sessionStore: sessionStore
            )
        )
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/subscription")!,
            proxies: [ClashProxy(name: "Stable Relay", type: "vmess", server: "2.2.2.2", port: 443)]
        )

        try await adapter.start(with: config)
        await adapter.stop()

        let status = await adapter.status()
        let session = await sessionStore.current()
        XCTAssertEqual(status, ClashAdapterStatus(state: .stopped, lastConfigurationID: config.configurationID))
        XCTAssertEqual(session?.runtimeState, .stopped)
    }

    func testStartFailurePersistsFailedStatus() async {
        let sessionStore = TunnelSessionStore(store: InMemoryDataStore(), key: "rockeroom.tunnel-session")
        let adapter = ClashAdapter(
            engine: TunnelManagerClashEngine(
                tunnelManager: FailingTestTunnelManager(),
                sessionStore: sessionStore
            )
        )
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://start-failure.example.com/subscription")!,
            proxies: [ClashProxy(name: "Broken Relay", type: "ss", server: "3.3.3.3", port: 9000)]
        )

        do {
            try await adapter.start(with: config)
            XCTFail("Expected tunnel start failure")
        } catch {}

        let session = await sessionStore.current()
        XCTAssertEqual(session?.configurationID, config.configurationID)
        XCTAssertEqual(session?.runtimeState, .failed(message: "Could not start the RockeRoom tunnel."))
    }
}

private struct FailingTestTunnelManager: TunnelManaging {
    func startTunnel(configData: Data, configurationID: String) async throws {
        throw Failure.startFailed
    }

    func stopTunnel() async {}

    func status() async -> ClashAdapterStatus {
        ClashAdapterStatus(
            state: .failed(message: Failure.startFailed.localizedDescription),
            lastConfigurationID: "https://start-failure.example.com/subscription"
        )
    }

    private enum Failure: LocalizedError {
        case startFailed

        var errorDescription: String? {
            "Could not start the RockeRoom tunnel."
        }
    }
}
