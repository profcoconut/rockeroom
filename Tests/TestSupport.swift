import Foundation

@testable import SharedKit

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
