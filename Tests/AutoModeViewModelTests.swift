import XCTest
import Foundation

@testable import RockeRoom
@testable import SharedKit

@MainActor
final class AutoModeViewModelTests: XCTestCase {
    func testRestoreStateLoadsStoredSubscriptionAndRunningTunnelStatus() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            subscriptionName: "Primary",
            proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
        )
        try await repository.save(link: "https://example.com/sub", config: config)
        try await sessionStore.sync(
            status: ClashAdapterStatus(state: .running, lastConfigurationID: config.configurationID),
            configurationID: config.configurationID
        )

        let viewModel = AutoModeViewModel(
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.stopped),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor()),
            snapshotStore: snapshotStore,
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.subscriptionLink, "https://example.com/sub")
        XCTAssertEqual(viewModel.status, AutoModeStatus.running)
        XCTAssertEqual(viewModel.tunnelStatus.state, ClashAdapterStatus.State.running)
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Primary")
    }

    func testImportFailurePreservesExistingStoredSubscription() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let initialConfig = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/original")!,
            subscriptionName: "Original",
            proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
        )
        try await repository.save(link: "https://example.com/original", config: initialConfig)

        let viewModel = AutoModeViewModel(
            importer: ClashSubscriptionImporter(fetcher: TestFailingFetcher()),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.stopped),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor()),
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        await viewModel.restoreState()
        viewModel.importSubscriptionLink("https://example.com/invalid")
        try? await Task.sleep(nanoseconds: 50_000_000)

        let current = await repository.current()

        XCTAssertEqual(current?.subscriptionLink, "https://example.com/original")
        XCTAssertEqual(viewModel.status, AutoModeStatus.failed(message: "Could not load the Clash subscription link."))
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Original")
    }

    func testRestoreStateLoadsPersistedSnapshotAndPinnedRecommendation() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            subscriptionName: "Primary",
            proxies: [
                ClashProxy(name: "Fast Relay", type: "ss"),
                ClashProxy(name: "Stable Relay", type: "vmess")
            ]
        )
        try await repository.save(link: "https://example.com/sub", config: config)
        try await sessionStore.markStopped(configurationID: config.configurationID)
        await snapshotStore.update(
            ResultSnapshot(
                sourceURL: config.sourceURL,
                candidates: [
                    ProbeCandidateResult(
                        candidateID: "fast",
                        label: "Fast Relay",
                        metrics: [ProbeMetric(name: "latency", value: 120, unit: "ms", betterIsHigher: false)],
                        score: 0.95,
                        confidence: 0.91,
                        freshness: 0.94
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [ProbeMetric(name: "latency", value: 150, unit: "ms", betterIsHigher: false)],
                        score: 0.78,
                        confidence: 0.88,
                        freshness: 0.94
                    )
                ],
                overallConfidence: 0.9,
                freshness: 0.93,
                isPartial: false
            )
        )
        try await pinStateStore.update(.pinned(candidateID: "stable"))

        let viewModel = AutoModeViewModel(
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.stopped),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor()),
            snapshotStore: snapshotStore,
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        await viewModel.restoreState()

        guard case .holding(let hold) = viewModel.recommendationState else {
            return XCTFail("Expected a held recommendation")
        }

        XCTAssertEqual(hold.reason, .pinned)
        XCTAssertEqual(viewModel.status, AutoModeStatus.ready)
        XCTAssertTrue(viewModel.pinnedProvider)
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Stable Relay")
    }

    func testPinnedCandidateRemainsCurrentSetupWhenEvidenceTurnsStale() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            subscriptionName: "Primary",
            proxies: [
                ClashProxy(name: "Fast Relay", type: "ss"),
                ClashProxy(name: "Stable Relay", type: "vmess")
            ]
        )
        try await repository.save(link: "https://example.com/sub", config: config)
        try await sessionStore.sync(
            status: ClashAdapterStatus(state: .running, lastConfigurationID: config.configurationID),
            configurationID: config.configurationID
        )
        await snapshotStore.update(
            ResultSnapshot(
                sourceURL: config.sourceURL,
                generatedAt: Date(timeIntervalSince1970: 400),
                candidates: [
                    ProbeCandidateResult(
                        candidateID: "fast",
                        label: "Fast Relay",
                        metrics: [ProbeMetric(name: "latency", value: 120, unit: "ms", betterIsHigher: false)],
                        score: 0.95,
                        confidence: 0.91,
                        freshness: 0.95
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [ProbeMetric(name: "latency", value: 150, unit: "ms", betterIsHigher: false)],
                        score: 0.78,
                        confidence: 0.88,
                        freshness: 0.95
                    )
                ],
                overallConfidence: 0.9,
                freshness: 0.95,
                isPartial: false
            )
        )
        try await pinStateStore.update(.pinned(candidateID: "stable"))

        let viewModel = AutoModeViewModel(
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.running),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor()),
            snapshotStore: snapshotStore,
            recommendationPolicy: RecommendationPolicy(staleFreshnessThreshold: 0.5),
            refreshCoordinator: RefreshCoordinator(currentWindow: 60, staleWindow: 120, staleFreshnessThreshold: 0.5),
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore,
            now: { Date(timeIntervalSince1970: 500) }
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Stable Relay")
        XCTAssertTrue(viewModel.pinnedProvider)
        XCTAssertEqual(viewModel.freshnessText, "Freshness: stale")
    }
}
