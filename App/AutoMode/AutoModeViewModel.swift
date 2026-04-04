import Foundation
import SharedKit

@MainActor
final class AutoModeViewModel: ObservableObject {
    @Published var subscriptionLink: String = "https://example.com/clash-subscription"
    @Published var status: AutoModeStatus = .idle
    @Published var snapshot: ResultSnapshot?
    @Published var recommendationState: RecommendationState = .idle
    @Published var tunnelStatus: ClashAdapterStatus = ClashAdapterStatus()
    @Published private(set) var refreshHintText: String?

    private let importer: ClashSubscriptionImporter
    private let adapter: ClashAdapter
    private let runner: ProbeRunner
    private let snapshotStore: ResultSnapshotStore
    private let recommendationPolicy: RecommendationPolicy
    private let refreshCoordinator: RefreshCoordinator
    private let subscriptionRepository: SubscriptionRepository
    private let tunnelSessionStore: TunnelSessionStore
    private let pinStateStore: PinStateStore
    private let destinationAssignmentStore: DestinationRoutingAssignmentStore
    private let now: @Sendable () -> Date
    private var subscriptionConfig: SubscriptionConfig?
    @Published private(set) var pinState: PinState = .none
    @Published private(set) var destinationAssignment: DestinationRoutingAssignments?

    var hasImportedSubscription: Bool {
        subscriptionConfig != nil
    }

    var hasBenchmarkResults: Bool {
        snapshot?.candidates.isEmpty == false
    }

    var importErrorMessage: String? {
        guard case .failed(let message) = status else { return nil }
        return message
    }

    var subscriptionDisplayName: String {
        subscriptionConfig?.subscriptionName ?? "Imported Clash subscription"
    }

    init(
        importer: ClashSubscriptionImporter? = nil,
        adapter: ClashAdapter? = nil,
        runner: ProbeRunner? = nil,
        snapshotStore: ResultSnapshotStore = ResultSnapshotStore(),
        recommendationPolicy: RecommendationPolicy = RecommendationPolicy(),
        refreshCoordinator: RefreshCoordinator = RefreshCoordinator(),
        subscriptionRepository: SubscriptionRepository = SubscriptionRepository(),
        tunnelSessionStore: TunnelSessionStore = TunnelSessionStore(),
        pinStateStore: PinStateStore = PinStateStore(),
        destinationAssignmentStore: DestinationRoutingAssignmentStore = DestinationRoutingAssignmentStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.subscriptionRepository = subscriptionRepository
        self.tunnelSessionStore = tunnelSessionStore
        self.pinStateStore = pinStateStore
        self.destinationAssignmentStore = destinationAssignmentStore
        self.importer = importer ?? Self.makeImporter()
        self.adapter = adapter ?? Self.makeAdapter(tunnelSessionStore: tunnelSessionStore)
        self.runner = runner ?? ProbeRunner(executor: DemoProbeExecutor())
        self.snapshotStore = snapshotStore
        self.recommendationPolicy = recommendationPolicy
        self.refreshCoordinator = refreshCoordinator
        self.now = now
    }

    func resetStoredStateIfNeeded() async {
        guard ProcessInfo.processInfo.environment["ROCKEROOM_RESET_STORAGE"] == "1" else { return }
        await subscriptionRepository.clear()
        await tunnelSessionStore.clear()
        await snapshotStore.clear()
        await pinStateStore.clear()
        await destinationAssignmentStore.clear()
        subscriptionConfig = nil
        snapshot = nil
        pinState = .none
        recommendationState = .idle
        refreshHintText = nil
        tunnelStatus = ClashAdapterStatus()
        status = .idle
        destinationAssignment = nil
    }

    /// Seeds destination assignment state for E2E harness purposes.
    /// Saves to the store and updates in-memory state without triggering full restore.
    /// The in-memory destinationAssignment is updated so subsequent restoreState() calls
    /// don't overwrite it (restoreState() only sets it if the store was previously nil).
    func seedDestinationAssignment(_ assignments: DestinationRoutingAssignments) async {
        await destinationAssignmentStore.save(assignments)
        destinationAssignment = assignments
    }

    func restoreState() async {
        let storedSubscription = await subscriptionRepository.current()
        subscriptionLink = storedSubscription?.subscriptionLink ?? subscriptionLink
        subscriptionConfig = storedSubscription?.config
        pinState = await pinStateStore.current()
        destinationAssignment = await destinationAssignmentStore.current()
        let storedSnapshot = await snapshotStore.current()

        let persistedSession = await tunnelSessionStore.current()
        let liveStatus = await adapter.status()
        tunnelStatus = resolvedRestoreStatus(liveStatus: liveStatus, persistedSession: persistedSession)
        applyRefreshAssessment(rawSnapshot: storedSnapshot, trigger: .restore)
        applyStatusForCurrentState()
    }

    func handleAppDidBecomeActive() async {
        let rawSnapshot: ResultSnapshot?
        if let snapshot {
            rawSnapshot = snapshot
        } else {
            rawSnapshot = await snapshotStore.current()
        }
        applyRefreshAssessment(rawSnapshot: rawSnapshot, trigger: .foreground)
        applyStatusForCurrentState()
    }

    func importSubscriptionLink(_ link: String) {
        subscriptionLink = link
        status = .importing

        Task {
            let result = await importer.importSubscription(from: link)
            switch result {
            case .accepted(let config):
                do {
                    try await subscriptionRepository.save(link: link, config: config)
                    try await tunnelSessionStore.markStopped(configurationID: config.configurationID)
                    subscriptionConfig = config
                    tunnelStatus = ClashAdapterStatus(state: .stopped, lastConfigurationID: config.configurationID)
                    pinState = .none
                    await pinStateStore.clear()
                    recommendationState = .idle
                    refreshHintText = nil
                    snapshot = nil
                    await snapshotStore.clear()
                    status = .ready
                } catch {
                    status = .failed(message: error.localizedDescription)
                }
            case .rejected(let failure):
                if subscriptionConfig == nil {
                    recommendationState = .rejected(
                        RecommendationRejection(reason: .invalidSnapshot, message: failure.message)
                    )
                    snapshot = nil
                }
                status = .failed(message: failure.message)
            }
        }
    }

    func optimize() {
        guard let subscriptionConfig else {
            status = .failed(message: "Import a Clash subscription link before running a benchmark.")
            return
        }

        status = .optimizing
        tunnelStatus = ClashAdapterStatus(state: .starting, lastConfigurationID: subscriptionConfig.configurationID)

        Task {
            do {
                try await adapter.start(with: subscriptionConfig)
                tunnelStatus = await adapter.status()

                let newSnapshot = await runner.run(
                    subscription: subscriptionConfig,
                    sourceURL: subscriptionConfig.sourceURL,
                    now: now()
                )
                await snapshotStore.update(newSnapshot)
                applyRefreshAssessment(rawSnapshot: newSnapshot, trigger: .explicit)
                status = .running
            } catch {
                let message = error.localizedDescription
                tunnelStatus = ClashAdapterStatus(
                    state: .failed(message: message),
                    lastConfigurationID: subscriptionConfig.configurationID
                )
                status = .failed(message: message)
                if self.snapshot == nil {
                    recommendationState = .rejected(
                        RecommendationRejection(reason: .invalidSnapshot, message: message)
                    )
                }
            }
        }
    }

    func pinCurrentProvider() async {
        guard let selectedID = activeCandidate?.candidateID else { return }
        await pin(candidateID: selectedID)
    }

    func pin(candidateID: String) async {
        guard snapshot?.candidates.contains(where: { $0.candidateID == candidateID }) == true else { return }
        pinState = .pinned(candidateID: candidateID)
        try? await pinStateStore.update(pinState)
        reevaluateRecommendation()
    }

    func unpinCurrentProvider() async {
        pinState = .none
        try? await pinStateStore.update(pinState)
        reevaluateRecommendation()
    }

    var currentTitle: String {
        switch recommendationState {
        case .recommended:
            return "Recommended setup"
        case .holding:
            return "Best current setup"
        case .rejected:
            return "Recommendation unavailable"
        case .idle, .evaluating:
            switch status {
            case .running:
                return hasBenchmarkResults ? "Benchmark complete" : "Tunnel running"
            case .startingTunnel, .optimizing:
                return "Running benchmark"
            case .failed:
                return hasBenchmarkResults ? "Benchmark needs refresh" : "Benchmark unavailable"
            case .idle:
                return "Import a Clash subscription"
            case .importing:
                return "Importing Clash subscription"
            case .ready:
                return "Run your first benchmark"
            }
        }
    }

    var currentSetupText: String {
        if let selected = activeCandidate {
            return "Current setup: \(selected.label)"
        }
        if let subscriptionConfig {
            return "Current setup: \(subscriptionConfig.subscriptionName ?? "imported Clash subscription")"
        }
        return "Current setup: no subscription imported"
    }

    var recommendationSummaryText: String {
        switch recommendationState {
        case .recommended(let summary):
            return "Why this: \(resolvedCandidateLabel(for: summary.selectedCandidateID)) scored highest with fresh, confident measurements."
        case .holding(let hold):
            return holdMessage(for: hold)
        case .rejected(let rejection):
            return rejection.message
        case .idle:
            switch status {
            case .idle:
                return "Import a Clash subscription link to get started."
            case .importing:
                return "Validating the Clash subscription and preparing it for use."
            case .ready:
                return "Subscription ready. Run Benchmark to measure providers and get a recommendation."
            case .startingTunnel:
                return "Starting the tunnel and measuring the current candidates."
            case .running:
                return hasBenchmarkResults
                    ? "Benchmark complete. Refresh Benchmark any time to update the recommendation."
                    : "Tunnel is running. Run Benchmark to collect recommendation data."
            case .optimizing:
                return "Testing providers and building the current recommendation."
            case .failed(let message):
                return message
            }
        case .evaluating:
            return "Testing providers and building the current recommendation."
        }
    }

    var confidenceText: String {
        switch recommendationState {
        case .recommended(let summary):
            return "Confidence: \(confidenceLabel(for: summary.confidence))"
        case .holding(let hold):
            return "Confidence: \(confidenceLabel(for: hold.confidence))"
        case .rejected:
            return "Confidence: unavailable"
        case .idle, .evaluating:
            return "Confidence: pending"
        }
    }

    var freshnessText: String {
        switch recommendationState {
        case .recommended(let summary):
            return "Freshness: \(freshnessLabel(for: summary.freshness))"
        case .holding(let hold):
            return "Freshness: \(freshnessLabel(for: hold.freshness))"
        case .rejected:
            return "Freshness: unavailable"
        case .idle, .evaluating:
            return "Freshness: pending"
        }
    }

    var tunnelStatusText: String {
        switch tunnelStatus.state {
        case .stopped:
            return "Tunnel: stopped"
        case .starting:
            return "Tunnel: starting"
        case .running:
            return "Tunnel: running"
        case .failed(let message):
            return "Tunnel: failed - \(message)"
        }
    }

    var pinnedProvider: Bool {
        pinState.candidateID != nil
    }

    var proofRows: [ProofRow] {
        let payload = currentProofPayload
        guard !payload.deltas.isEmpty else {
            return [
                ProofRow(title: "Latency", value: "Pending"),
                ProofRow(title: "Jitter", value: "Pending"),
                ProofRow(title: "Packet Loss", value: "Pending")
            ]
        }

        return Array(payload.deltas.prefix(3)).map { delta in
            ProofRow(
                title: delta.metricName,
                value: formatted(delta: delta)
            )
        }
    }

    var currentProofPayload: ProofPayload {
        switch recommendationState {
        case .recommended(let summary):
            return summary.proof
        case .holding(let hold):
            return hold.proof ?? emptyProofPayload
        case .rejected, .idle, .evaluating:
            return emptyProofPayload
        }
    }

    private var emptyProofPayload: ProofPayload {
        ProofPayload(
            title: "Why this?",
            subtitle: "Run Benchmark to generate measurable proof.",
            deltas: [],
            confidence: 0,
            freshness: 0,
            isPartial: false
        )
    }

    var benchmarkActionTitle: String {
        hasBenchmarkResults ? "Refresh Benchmark" : "Run Benchmark"
    }

    var isBenchmarkInFlight: Bool {
        switch status {
        case .importing, .startingTunnel, .optimizing:
            return true
        case .idle, .ready, .running, .failed:
            return false
        }
    }

    var homeMetricSummaries: [HomeMetricSummary] {
        HomeMetric.summaryList(for: activeCandidate)
    }

    var homeRecommendationSubtitle: String {
        if !hasBenchmarkResults {
            return "Run Benchmark to measure latency, jitter, packet loss, and throughput before RockeRoom recommends anything."
        }

        switch recommendationState {
        case .recommended(let summary):
            return "\(resolvedCandidateLabel(for: summary.selectedCandidateID)) leads with the strongest current benchmark."
        case .holding(let hold):
            return holdMessage(for: hold)
        case .rejected(let rejection):
            return rejection.message
        case .idle, .evaluating:
            return recommendationSummaryText
        }
    }

    var homeRecommendationStatus: String {
        if !hasBenchmarkResults {
            return "No benchmark run yet"
        }

        switch recommendationState {
        case .recommended:
            return "Measured recommendation"
        case .holding:
            return "Measured hold"
        case .rejected:
            return "Recommendation unavailable"
        case .idle, .evaluating:
            return "Benchmark in progress"
        }
    }

    private var activeCandidate: ProbeCandidateResult? {
        guard let snapshot else { return nil }

        if let pinnedID = pinState.candidateID {
            return snapshot.candidates.first(where: { $0.candidateID == pinnedID })
        }

        if case .recommended(let summary) = recommendationState {
            return snapshot.candidates.first(where: { $0.candidateID == summary.selectedCandidateID })
        }

        return snapshot.bestCandidate
    }

    private func reevaluateRecommendation() {
        applyRefreshAssessment(rawSnapshot: snapshot, trigger: .explicit)
    }

    private func applyRefreshAssessment(rawSnapshot: ResultSnapshot?, trigger: RefreshTrigger) {
        let assessment = refreshCoordinator.evaluate(
            snapshot: rawSnapshot,
            tunnelStatus: tunnelStatus,
            trigger: trigger,
            now: now()
        )
        snapshot = assessment.snapshot
        refreshHintText = refreshHint(for: assessment)

        guard let snapshot else {
            recommendationState = .idle
            return
        }

        recommendationState = recommendationPolicy.evaluate(snapshot: snapshot, pinState: pinState)
    }

    private func applyStatusForCurrentState() {
        guard subscriptionConfig != nil else {
            status = .idle
            return
        }

        switch tunnelStatus.state {
        case .stopped:
            status = .ready
        case .starting:
            status = .startingTunnel
        case .running:
            status = .running
        case .failed(let message):
            status = .failed(message: message)
        }
    }

    private func resolvedRestoreStatus(liveStatus: ClashAdapterStatus, persistedSession: TunnelSession?) -> ClashAdapterStatus {
        if
            liveStatus.lastConfigurationID == nil,
            case .stopped = liveStatus.state,
            let persistedSession
        {
            return ClashAdapterStatus(
                state: persistedSession.runtimeState.asAdapterState,
                lastConfigurationID: persistedSession.configurationID
            )
        }

        return liveStatus
    }

    private func holdMessage(for hold: RecommendationHold) -> String {
        switch hold.reason {
        case .pinned:
            return "Pinned provider active. Manual selection stays in effect until you unpin it in Expert Console."
        case .lowConfidence:
            return "Best current setup. Confidence is still building, so RockeRoom will not switch yet."
        case .insignificantDelta:
            return "Best current setup. The measured gain is too small to justify switching."
        case .staleData:
            return "Best current setup. Measurements are getting stale, so RockeRoom is holding until a refresh."
        case .noCandidates:
            return "No measurable candidates are available yet."
        }
    }

    private func refreshHint(for assessment: RefreshAssessment) -> String? {
        switch assessment.refreshAvailability {
        case .unavailable:
            return nil
        case .explicitOnly:
            return "Stale evidence. Run Benchmark to refresh before RockeRoom changes anything."
        case .recommended:
            return "Refresh available. Run Benchmark again to update stale evidence."
        }
    }

    private func confidenceLabel(for value: Double) -> String {
        switch value {
        case 0.85...:
            return "high"
        case 0.65...:
            return "medium"
        case 0.01...:
            return "low"
        default:
            return "unavailable"
        }
    }

    private func freshnessLabel(for value: Double) -> String {
        switch value {
        case 0.85...:
            return "just measured"
        case 0.5...:
            return "current"
        case 0.01...:
            return "stale"
        default:
            return "pending"
        }
    }

    private func formatted(delta: ProofDelta) -> String {
        let difference = delta.candidateValue - delta.currentValue
        let sign = difference > 0 ? "+" : ""
        if delta.unit == "ms" {
            return "\(sign)\(Int(difference))\(delta.unit)"
        }
        return "\(sign)\(Int(difference.rounded()))\(delta.unit)"
    }

    private func resolvedCandidateLabel(for candidateID: String) -> String {
        snapshot?.candidates.first(where: { $0.candidateID == candidateID })?.label ?? candidateID
    }

    private static func makeImporter() -> ClashSubscriptionImporter {
        if ProcessInfo.processInfo.environment["ROCKEROOM_USE_DEMO_FETCHER"] == "1" {
            return ClashSubscriptionImporter(fetcher: LocalDevelopmentSubscriptionFetcher())
        }

        return ClashSubscriptionImporter()
    }

    private static func makeAdapter(tunnelSessionStore: TunnelSessionStore) -> ClashAdapter {
        if ProcessInfo.processInfo.environment["ROCKEROOM_USE_DEMO_TUNNEL"] == "1" {
            let manager: any TunnelManaging
            if ProcessInfo.processInfo.environment["ROCKEROOM_DEMO_TUNNEL_FAILURE"] == "1" {
                manager = FailingTunnelManager()
            } else {
                manager = InMemoryTunnelManager()
            }
            return ClashAdapter(
                engine: TunnelManagerClashEngine(
                    tunnelManager: manager,
                    sessionStore: tunnelSessionStore
                )
            )
        }

        return ClashAdapter(sessionStore: tunnelSessionStore)
    }
}

enum AutoModeStatus: Equatable {
    case idle
    case importing
    case ready
    case startingTunnel
    case running
    case optimizing
    case failed(message: String)
}

struct ProofRow: Equatable {
    let title: String
    let value: String
}

struct HomeMetricSummary: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String
    let note: String?
}

private enum HomeMetric: String, CaseIterable {
    case latency = "Latency"
    case jitter = "Jitter"
    case packetLoss = "Packet Loss"
    case throughput = "Throughput"

    static func summaryList(for candidate: ProbeCandidateResult?) -> [HomeMetricSummary] {
        allCases.map { metric in
            metric.summary(for: candidate)
        }
    }

    private func summary(for candidate: ProbeCandidateResult?) -> HomeMetricSummary {
        guard let metric = candidate?.metrics.first(where: { $0.name == rawValue }) else {
            return HomeMetricSummary(
                id: rawValue,
                title: rawValue,
                value: "Unavailable",
                note: self == .throughput ? "Not measured in this benchmark." : nil
            )
        }

        let rendered: String
        switch metric.unit {
        case "ms":
            rendered = "\(Int(metric.value.rounded()))\(metric.unit)"
        case "%":
            rendered = String(format: "%.1f%@", metric.value, metric.unit)
        default:
            rendered = "\(Int(metric.value.rounded())) \(metric.unit)"
        }

        return HomeMetricSummary(id: rawValue, title: rawValue, value: rendered, note: nil)
    }
}

private extension TunnelSession.RuntimeState {
    var asAdapterState: ClashAdapterStatus.State {
        switch self {
        case .stopped:
            return .stopped
        case .starting:
            return .starting
        case .running:
            return .running
        case .failed(let message):
            return .failed(message: message)
        }
    }
}

private struct LocalDevelopmentSubscriptionFetcher: SubscriptionContentFetching {
    func fetch(from url: URL) async throws -> Data {
        guard url.host?.contains("invalid") != true else {
            throw URLError(.badServerResponse)
        }

        if let payload = ProcessInfo.processInfo.environment["ROCKEROOM_DEMO_SUBSCRIPTION_PAYLOAD_B64"] {
            return Data(payload.utf8)
        }

        let yaml = """
        proxies:
          - name: Fast Relay
            type: ss
            server: 1.1.1.1
            port: 8388
            udp: true
          - name: Stable Relay
            type: vmess
            server: 2.2.2.2
            port: 443
            udp: true
        """
        return Data(yaml.utf8)
    }
}

private struct DemoProbeExecutor: ProbeExecuting {
    func probe(_ candidate: ClashProxy) async -> ProbeCandidateResult {
        let metrics: [ProbeMetric]
        let score: Double
        let confidence: Double
        let freshness: Double
        let fingerprint = [candidate.name, candidate.server ?? ""].joined(separator: " ").lowercased()

        switch fingerprint {
        case let value where value.localizedCaseInsensitiveContains("fast") || value.localizedCaseInsensitiveContains("hong kong") || value.localizedCaseInsensitiveContains("hk-"):
            metrics = [
                ProbeMetric(name: "Latency", value: 38, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Jitter", value: 4, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Packet Loss", value: 0.2, unit: "%", betterIsHigher: false),
                ProbeMetric(name: "Throughput", value: 182, unit: "Mbps", betterIsHigher: true)
            ]
            score = 0.91
            confidence = 0.88
            freshness = 0.96
        case let value where value.localizedCaseInsensitiveContains("japan") || value.localizedCaseInsensitiveContains("jp-"):
            metrics = [
                ProbeMetric(name: "Latency", value: 54, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Jitter", value: 7, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Packet Loss", value: 0.5, unit: "%", betterIsHigher: false),
                ProbeMetric(name: "Throughput", value: 148, unit: "Mbps", betterIsHigher: true)
            ]
            score = 0.82
            confidence = 0.85
            freshness = 0.95
        default:
            metrics = [
                ProbeMetric(name: "Latency", value: 71, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Jitter", value: 9, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Packet Loss", value: 0.8, unit: "%", betterIsHigher: false),
                ProbeMetric(name: "Throughput", value: 124, unit: "Mbps", betterIsHigher: true)
            ]
            score = 0.74
            confidence = 0.84
            freshness = 0.93
        }

        return ProbeCandidateResult(
            candidateID: candidate.id,
            label: candidate.name,
            metrics: metrics,
            score: score,
            confidence: confidence,
            freshness: freshness,
            isPartial: false
        )
    }
}

private struct FailingTunnelManager: TunnelManaging {
    func startTunnel(configData: Data, configurationID: String) async throws {
        throw DemoTunnelError.startFailed
    }

    func stopTunnel() async {}

    func status() async -> ClashAdapterStatus {
        ClashAdapterStatus(state: .failed(message: DemoTunnelError.startFailed.localizedDescription))
    }
}

private enum DemoTunnelError: LocalizedError {
    case startFailed

    var errorDescription: String? {
        "Could not start the RockeRoom tunnel."
    }
}
