import XCTest

@testable import RockeRoom
@testable import SharedKit

@MainActor
final class HomeSummaryMetricTests: XCTestCase {
    func testHomeSummaryExposesFourMetricsForActiveCandidate() async throws {
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
        await snapshotStore.update(
            ResultSnapshot(
                sourceURL: config.sourceURL,
                candidates: [
                    ProbeCandidateResult(
                        candidateID: "fast",
                        label: "Fast Relay",
                        metrics: [
                            ProbeMetric(name: "Latency", value: 42, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Jitter", value: 6, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Packet Loss", value: 0.4, unit: "%", betterIsHigher: false),
                            ProbeMetric(name: "Throughput", value: 155, unit: "Mbps", betterIsHigher: true)
                        ],
                        score: 0.94,
                        confidence: 0.91,
                        freshness: 0.95
                    )
                ],
                selectedCandidateID: "fast",
                overallConfidence: 0.91,
                freshness: 0.95,
                isPartial: false
            )
        )

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
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.homeMetricSummaries.map(\.title), ["Latency", "Jitter", "Packet Loss", "Throughput"])
        XCTAssertEqual(viewModel.homeMetricSummaries.map(\.value), ["42ms", "6ms", "0.4%", "155 Mbps"])
        XCTAssertEqual(viewModel.homeRecommendationStatus, "Measured recommendation")
    }

    func testHomeSummaryShowsMeasuredHoldForPinnedCurrentSetup() async throws {
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
                        metrics: [
                            ProbeMetric(name: "Latency", value: 42, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Jitter", value: 6, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Packet Loss", value: 0.4, unit: "%", betterIsHigher: false),
                            ProbeMetric(name: "Throughput", value: 155, unit: "Mbps", betterIsHigher: true)
                        ],
                        score: 0.94,
                        confidence: 0.91,
                        freshness: 0.95
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [
                            ProbeMetric(name: "Latency", value: 51, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Jitter", value: 9, unit: "ms", betterIsHigher: false),
                            ProbeMetric(name: "Packet Loss", value: 0.2, unit: "%", betterIsHigher: false),
                            ProbeMetric(name: "Throughput", value: 142, unit: "Mbps", betterIsHigher: true)
                        ],
                        score: 0.82,
                        confidence: 0.88,
                        freshness: 0.95
                    )
                ],
                selectedCandidateID: "fast",
                overallConfidence: 0.91,
                freshness: 0.95,
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

        XCTAssertEqual(viewModel.homeRecommendationStatus, "Measured hold")
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Stable Relay")
        XCTAssertTrue(viewModel.pinnedProvider)
    }
}
