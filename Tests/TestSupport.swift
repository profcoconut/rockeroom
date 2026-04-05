import Foundation

@testable import SharedKit

struct DestinationCatalogFixtureLoader {
    func loadAll() throws -> [RoutingDestination] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: fixtureDirectoryURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )

        return contents
            .filter { ["yaml", "yml"].contains($0.pathExtension) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap(parseFixture)
    }

    private var fixtureDirectoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("routing-destinations")
    }

    private func parseFixture(at url: URL) -> RoutingDestination? {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var slug: String?
        var label: String?
        var ruleFamily: String?
        var fallback = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<colon.lowerBound])
            let value = String(trimmed[colon.upperBound...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "id":
                if !value.isEmpty { slug = value }
            case "label":
                if !value.isEmpty { label = value }
            case "rule_family":
                if !value.isEmpty { ruleFamily = value }
            case "fallback":
                fallback = value == "true"
            default:
                break
            }
        }

        guard let slug, let label, let ruleFamily else {
            return nil
        }

        return RoutingDestination(slug: slug, label: label, ruleFamily: ruleFamily, isFallback: fallback)
    }
}

struct TestStubFetcher: SubscriptionContentFetching {
    let data: Data

    func fetch(from url: URL) async throws -> Data {
        data
    }
}

struct TestThrowingFetcher: SubscriptionContentFetching {
    func fetch(from url: URL) async throws -> Data {
        throw URLError(.badServerResponse)
    }
}

struct TestFailingFetcher: SubscriptionContentFetching {
    func fetch(from url: URL) async throws -> Data {
        throw URLError(.badServerResponse)
    }
}

struct TestMappingFetcher: SubscriptionContentFetching {
    let payloads: [String: Data]

    func fetch(from url: URL) async throws -> Data {
        guard let data = payloads[url.absoluteString] else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct TestStubProbeExecutor: ProbeExecuting {
    func probe(_ candidate: ClashProxy) async -> ProbeCandidateResult {
        ProbeCandidateResult(
            candidateID: candidate.id,
            label: candidate.name,
            metrics: [
                ProbeMetric(name: "Latency", value: 50, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Jitter", value: 5, unit: "ms", betterIsHigher: false),
                ProbeMetric(name: "Packet Loss", value: 0.4, unit: "%", betterIsHigher: false),
                ProbeMetric(name: "Throughput", value: 160, unit: "Mbps", betterIsHigher: true)
            ],
            score: 0.9,
            confidence: 0.9,
            freshness: 1.0
        )
    }
}

actor TestStubTunnelManager: TunnelManaging {
    private let statusAfterStart: ClashAdapterStatus.State
    private var currentStatus = ClashAdapterStatus()

    init(statusAfterStart: ClashAdapterStatus.State) {
        self.statusAfterStart = statusAfterStart
    }

    func startTunnel(configData: Data, configurationID: String) async throws {
        currentStatus = ClashAdapterStatus(state: statusAfterStart, lastConfigurationID: configurationID)
    }

    func stopTunnel() async {
        currentStatus = ClashAdapterStatus(state: .stopped, lastConfigurationID: currentStatus.lastConfigurationID)
    }

    func status() async -> ClashAdapterStatus {
        currentStatus
    }
}

actor TestFailingTunnelManager: TunnelManaging {
    func startTunnel(configData: Data, configurationID: String) async throws {
        throw Failure.startFailed
    }

    func stopTunnel() async {}

    func status() async -> ClashAdapterStatus {
        ClashAdapterStatus(state: .failed(message: Failure.startFailed.localizedDescription))
    }

    private enum Failure: LocalizedError {
        case startFailed

        var errorDescription: String? {
            "Could not start the tunnel."
        }
    }
}

actor TestSequencedDestinationRoutingEvaluator: DestinationRoutingEvaluating {
    private var evaluations: [DestinationRoutingAssignments]

    init(evaluations: [DestinationRoutingAssignments]) {
        self.evaluations = evaluations
    }

    func evaluate(
        subscription: SubscriptionConfig,
        sourceURL: URL,
        destinations: [RoutingDestination],
        previousAssignments: DestinationRoutingAssignments?,
        pinState: PinState,
        phase: AdaptiveRoutingPhase,
        now: Date
    ) async -> DestinationRoutingAssignments {
        if evaluations.isEmpty {
            return previousAssignments ?? DestinationRoutingAssignments(sourceURL: sourceURL.absoluteString)
        }
        if evaluations.count == 1 {
            return evaluations[0]
        }
        return evaluations.removeFirst()
    }
}

func makeDestinationAssignments(
    sourceURL: String = "https://example.com/sub",
    selectedDestinationID: String = "openai",
    providerByDestination: [String: String],
    environment: NetworkEnvironment = .unknown,
    strategy: RoutingStrategy = .rule
) -> DestinationRoutingAssignments {
    var assignments = DestinationRoutingAssignments(sourceURL: sourceURL, selectedDestinationID: selectedDestinationID)
    for (destinationID, provider) in providerByDestination {
        assignments.insert(
            DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: environment,
                    destinationID: destinationID,
                    providerID: provider,
                    strategy: strategy
                ),
                mode: .auto,
                assignedProviderLabel: provider,
                source: .automaticSelection,
                assignedAt: 1000,
                freshness: 0.95,
                status: .monitoring,
                measuredLatencyMS: provider.localizedCaseInsensitiveContains("fast") ? 34 : 58,
                failureRate: provider.localizedCaseInsensitiveContains("fast") ? 0.2 : 0.8,
                stabilityScore: 0.88,
                recentChangeSummary: "Monitoring current route health."
            )
        )
    }
    return assignments
}
