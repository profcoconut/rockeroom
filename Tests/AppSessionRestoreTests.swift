import XCTest

@testable import RockeRoom
@testable import SharedKit

@MainActor
final class AppSessionRestoreTests: XCTestCase {
    func testRestoreFallsBackToReadyWhenStoredSubscriptionExistsButTunnelIsStopped() async throws {
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
        try await sessionStore.markStopped(configurationID: config.configurationID)

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

        XCTAssertEqual(viewModel.status, AutoModeStatus.ready)
        XCTAssertEqual(viewModel.tunnelStatus.state, ClashAdapterStatus.State.stopped)
        XCTAssertEqual(viewModel.recommendationSummaryText, "Subscription ready. Run Benchmark to measure providers and get a recommendation.")
    }

    func testRestoreShowsPinnedCandidateFromPersistedSnapshot() async throws {
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
                        metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                        score: 0.95,
                        confidence: 0.91,
                        freshness: 0.94
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [ProbeMetric(name: "Latency", value: 150, unit: "ms", betterIsHigher: false)],
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

        XCTAssertTrue(viewModel.pinnedProvider)
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Stable Relay")
        XCTAssertEqual(viewModel.recommendationSummaryText, "Pinned provider active. Manual selection stays in effect until you unpin it in Expert Console.")
    }

    func testRestoreDecaysOldSnapshotAndShowsRefreshHintWhileTunnelIsRunning() async throws {
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
                generatedAt: Date(timeIntervalSince1970: 400),
                candidates: [
                    ProbeCandidateResult(
                        candidateID: "fast",
                        label: "Fast Relay",
                        metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                        score: 0.95,
                        confidence: 0.91,
                        freshness: 0.95
                    )
                ],
                overallConfidence: 0.9,
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
            recommendationPolicy: RecommendationPolicy(staleFreshnessThreshold: 0.5),
            refreshCoordinator: RefreshCoordinator(currentWindow: 60, staleWindow: 120, staleFreshnessThreshold: 0.5),
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore,
            now: { Date(timeIntervalSince1970: 500) }
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.status, AutoModeStatus.running)
        XCTAssertEqual(viewModel.freshnessText, "Freshness: stale")
        XCTAssertEqual(viewModel.recommendationSummaryText, "Best current setup. Measurements are getting stale, so RockeRoom is holding until a refresh.")
        XCTAssertEqual(viewModel.refreshHintText, "Refresh available. Run Benchmark again to update stale evidence.")

        let projection = EvidenceProjection.project(
            snapshot: viewModel.snapshot,
            recommendationState: viewModel.recommendationState,
            pinState: viewModel.pinState
        )
        XCTAssertEqual(projection.primaryState, .stale)
        XCTAssertTrue(projection.summaryText.contains("stale"))
    }

    func testRestoreLoadsDestinationAssignmentWithMultiDestinationAndSelectedID() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let assignmentStore = DestinationRoutingAssignmentStore(store: dataStore)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            subscriptionName: "Primary",
            proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
        )
        try await repository.save(link: "https://example.com/sub", config: config)
        try await sessionStore.markStopped(configurationID: config.configurationID)

        var assignments = DestinationRoutingAssignments()
        assignments.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000
            )
        )
        assignments.insert(
            DestinationRoutingAssignment(
                destinationID: "netflix",
                mode: .manual,
                assignedProviderID: "jp-01",
                assignedProviderLabel: "Japan 01",
                strategyName: "rule",
                source: .manualOverride,
                assignedAt: 1500
            )
        )
        assignments.selectedDestinationID = "netflix"
        await assignmentStore.save(assignments)

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
            pinStateStore: pinStateStore,
            destinationAssignmentStore: assignmentStore
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.destinationAssignment?.count, 2)
        XCTAssertEqual(viewModel.destinationAssignment?.selectedDestinationID, "netflix")
        XCTAssertEqual(viewModel.destinationAssignment?["openai"]?.mode, .auto)
        XCTAssertEqual(viewModel.destinationAssignment?["netflix"]?.mode, .manual)
    }

    func testRestorePreservesRecentHoldReasonWithoutImplyingBackgroundMonitoring() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let assignmentStore = DestinationRoutingAssignmentStore(store: dataStore)
        let config = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            subscriptionName: "Primary",
            proxies: [ClashProxy(name: "Fast Relay", type: "ss")]
        )
        try await repository.save(link: "https://example.com/sub", config: config)
        try await sessionStore.markStopped(configurationID: config.configurationID)

        var assignments = DestinationRoutingAssignments(sourceURL: config.sourceURL.absoluteString, selectedDestinationID: "openai")
        assignments.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "hk-01",
                assignedProviderLabel: "Hong Kong 01",
                strategyName: "rule",
                source: .automaticSelection,
                assignedAt: 1000,
                freshness: 0.46,
                status: .holding,
                holdReason: .staleEvidence,
                recentChangeSummary: "Holding OpenAI on Hong Kong 01 because the evidence is getting stale."
            )
        )
        await assignmentStore.save(assignments)

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
            pinStateStore: pinStateStore,
            destinationAssignmentStore: assignmentStore
        )

        await viewModel.restoreState()

        XCTAssertEqual(viewModel.destinationAssignment?["openai"]?.holdReason, .staleEvidence)
        XCTAssertEqual(
            viewModel.destinationAssignment?["openai"]?.recentChangeSummary,
            "Holding OpenAI on Hong Kong 01 because the evidence is getting stale."
        )
        XCTAssertEqual(viewModel.monitoringStatusText, "Monitoring available in foreground")
    }
}
