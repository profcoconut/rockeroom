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

    func testDebugResetClearsImportedAndMeasuredState() async throws {
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
                        metrics: [ProbeMetric(name: "Latency", value: 42, unit: "ms", betterIsHigher: false)],
                        score: 0.94,
                        confidence: 0.91,
                        freshness: 0.95
                    )
                ],
                overallConfidence: 0.9,
                freshness: 0.93,
                isPartial: false
            )
        )
        try await pinStateStore.update(.pinned(candidateID: "fast"))
        var assignments = DestinationRoutingAssignments(sourceURL: "https://example.com/sub")
        assignments.selectedDestinationID = "openai"
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
        await viewModel.resetDebugState()

        XCTAssertTrue(viewModel.hasRestoredSession)
        XCTAssertFalse(viewModel.hasImportedSubscription)
        XCTAssertEqual(viewModel.status, .idle)
        XCTAssertEqual(viewModel.subscriptionDisplayName, "Imported Clash subscription")
        XCTAssertFalse(viewModel.hasBenchmarkResults)
        let storedSubscription = await repository.current()
        let storedSnapshot = await snapshotStore.current()
        let storedPinState = await pinStateStore.current()
        let storedAssignments = await assignmentStore.current()

        XCTAssertNil(storedSubscription)
        XCTAssertNil(storedSnapshot)
        XCTAssertEqual(storedPinState, .none)
        XCTAssertNil(storedAssignments)
    }

    func testDebugDeterministicImportProducesNormalPostImportReadyState() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let assignmentStore = DestinationRoutingAssignmentStore(store: dataStore)

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
            pinStateStore: pinStateStore,
            destinationAssignmentStore: assignmentStore
        )

        await viewModel.importDebugSource(.deterministicDemo)

        XCTAssertTrue(viewModel.hasRestoredSession)
        XCTAssertTrue(viewModel.hasImportedSubscription)
        XCTAssertEqual(viewModel.status, .ready)
        XCTAssertFalse(viewModel.hasBenchmarkResults)
        XCTAssertEqual(viewModel.subscriptionDisplayName, "Imported Clash subscription")
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: imported Clash subscription")
    }

    func testDebugImportActivatesManualDebugRuntimeForBenchmarking() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)

        let standardRuntime = AutoModeRuntimeProfile(
            mode: .standard,
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestFailingTunnelManager(),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor())
        )
        let manualDebugRuntime = AutoModeRuntimeProfile(
            mode: .manualDebug,
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.running),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor())
        )

        let viewModel = AutoModeViewModel(
            runtimeProfile: standardRuntime,
            manualDebugRuntimeProfile: manualDebugRuntime,
            snapshotStore: snapshotStore,
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        XCTAssertEqual(viewModel.runtimeMode, .standard)

        await viewModel.importDebugSource(.deterministicDemo)
        XCTAssertEqual(viewModel.runtimeMode, .manualDebug)

        viewModel.optimize()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(viewModel.tunnelStatus.state, .running)
        XCTAssertEqual(viewModel.status, .running)
        XCTAssertTrue(viewModel.hasBenchmarkResults)
    }

    func testResetDebugStateReturnsToStandardRuntimeMode() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)

        let standardRuntime = AutoModeRuntimeProfile(
            mode: .standard,
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.stopped),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor())
        )
        let manualDebugRuntime = AutoModeRuntimeProfile(
            mode: .manualDebug,
            importer: ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data())),
            adapter: ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: TestStubTunnelManager(statusAfterStart: ClashAdapterStatus.State.running),
                    sessionStore: sessionStore
                )
            ),
            runner: ProbeRunner(executor: TestStubProbeExecutor())
        )

        let viewModel = AutoModeViewModel(
            runtimeProfile: standardRuntime,
            manualDebugRuntimeProfile: manualDebugRuntime,
            snapshotStore: snapshotStore,
            subscriptionRepository: repository,
            tunnelSessionStore: sessionStore,
            pinStateStore: pinStateStore
        )

        await viewModel.importDebugSource(.deterministicDemo)
        XCTAssertEqual(viewModel.runtimeMode, .manualDebug)

        await viewModel.resetDebugState()

        XCTAssertEqual(viewModel.runtimeMode, .standard)
        XCTAssertFalse(viewModel.hasImportedSubscription)
    }

    func testDebugLiveURLImportUsesSameFetcherPathAsNormalImport() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let liveURL = "https://provider.example.com/subscription"
        let importer = ClashSubscriptionImporter(
            fetcher: TestMappingFetcher(
                payloads: [
                    liveURL: Data(
                        """
                        proxies:
                          - name: Live Debug Relay
                            type: ss
                            server: 9.9.9.9
                            port: 8388
                        """.utf8
                    )
                ]
            )
        )

        let viewModel = AutoModeViewModel(
            importer: importer,
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

        await viewModel.importDebugSource(.liveURL(liveURL))

        XCTAssertEqual(viewModel.subscriptionLink, liveURL)
        XCTAssertTrue(viewModel.hasImportedSubscription)
        XCTAssertEqual(viewModel.status, .ready)
        XCTAssertFalse(viewModel.hasBenchmarkResults)
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: imported Clash subscription")
    }

    func testDebugLiveURLImportSurfacesSameFailureAsNormalBadImport() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
        let pinStateStore = PinStateStore(store: dataStore)
        let importer = ClashSubscriptionImporter(fetcher: TestFailingFetcher())

        let viewModel = AutoModeViewModel(
            importer: importer,
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

        await viewModel.importDebugSource(.liveURL("https://provider.example.com/invalid"))

        XCTAssertFalse(viewModel.hasImportedSubscription)
        XCTAssertEqual(viewModel.status, .failed(message: "Could not load the Clash subscription link."))
        XCTAssertEqual(viewModel.importErrorMessage, "Could not load the Clash subscription link.")
        XCTAssertFalse(viewModel.hasBenchmarkResults)
    }

    func testImportFailurePreservesExistingStoredSubscription() async throws {
        let dataStore = InMemoryDataStore()
        let repository = SubscriptionRepository(store: dataStore)
        let sessionStore = TunnelSessionStore(store: dataStore)
        let snapshotStore = ResultSnapshotStore(store: dataStore)
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
            snapshotStore: snapshotStore,
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

        guard case .holding(let hold) = viewModel.recommendationState else {
            return XCTFail("Expected a held recommendation")
        }

        XCTAssertEqual(hold.reason, .pinned)
        XCTAssertEqual(viewModel.status, AutoModeStatus.ready)
        XCTAssertTrue(viewModel.pinnedProvider)
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Stable Relay")
    }

    func testRestoreStateLoadsPersistedRecommendedCandidateAsCurrentSetup() async throws {
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
                candidates: [
                    ProbeCandidateResult(
                        candidateID: "fast",
                        label: "Fast Relay",
                        metrics: [ProbeMetric(name: "Latency", value: 42, unit: "ms", betterIsHigher: false)],
                        score: 0.94,
                        confidence: 0.91,
                        freshness: 0.95
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [ProbeMetric(name: "Latency", value: 61, unit: "ms", betterIsHigher: false)],
                        score: 0.72,
                        confidence: 0.88,
                        freshness: 0.95
                    )
                ],
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

        guard case .recommended(let summary) = viewModel.recommendationState else {
            return XCTFail("Expected a restored recommendation.")
        }

        XCTAssertEqual(summary.selectedCandidateID, "fast")
        XCTAssertEqual(viewModel.currentTitle, "Recommended setup")
        XCTAssertEqual(viewModel.currentSetupText, "Current setup: Fast Relay")
        XCTAssertEqual(
            viewModel.recommendationSummaryText,
            "Why this: Fast Relay scored highest with fresh, confident measurements."
        )
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
                        metrics: [ProbeMetric(name: "Latency", value: 120, unit: "ms", betterIsHigher: false)],
                        score: 0.95,
                        confidence: 0.91,
                        freshness: 0.95
                    ),
                    ProbeCandidateResult(
                        candidateID: "stable",
                        label: "Stable Relay",
                        metrics: [ProbeMetric(name: "Latency", value: 150, unit: "ms", betterIsHigher: false)],
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

    func testRestoreStateLoadsPersistedDestinationAssignments() async throws {
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
        assignments.sourceURL = "https://example.com/sub"
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
        assignments.selectedDestinationID = "openai"
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

        XCTAssertEqual(viewModel.destinationAssignment?.count, 1)
        XCTAssertEqual(viewModel.destinationAssignment?.selectedDestinationID, "openai")
        XCTAssertEqual(viewModel.destinationAssignment?["openai"]?.assignedProviderID, "hk-01")
        XCTAssertEqual(viewModel.destinationAssignment?["openai"]?.mode, .auto)
    }
}
