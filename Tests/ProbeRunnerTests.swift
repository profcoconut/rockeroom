import XCTest

@testable import SharedKit

final class ProbeRunnerTests: XCTestCase {
    func testProbeRunnerReturnsSharedSnapshotAndHonorsEarlyStop() async {
        let proxies = [
            ClashProxy(name: "Slow", type: "ss", server: "slow.example.com", port: 1),
            ClashProxy(name: "Fast", type: "ss", server: "fast.example.com", port: 2),
            ClashProxy(name: "NeverRuns", type: "ss", server: "never.example.com", port: 3)
        ]
        let config = SubscriptionConfig(sourceURL: URL(string: "https://example.com/sub")!, proxies: proxies)
        let executor = StubProbeExecutor(results: [
            "Slow": ProbeCandidateResult(candidateID: "Slow", label: "Slow", metrics: [ProbeMetric(name: "latency", value: 300, unit: "ms", betterIsHigher: false)], score: 0.25, confidence: 0.7, freshness: 1.0),
            "Fast": ProbeCandidateResult(candidateID: "Fast", label: "Fast", metrics: [ProbeMetric(name: "latency", value: 50, unit: "ms", betterIsHigher: false)], score: 0.9, confidence: 0.95, freshness: 1.0),
            "NeverRuns": ProbeCandidateResult(candidateID: "NeverRuns", label: "NeverRuns", metrics: [ProbeMetric(name: "latency", value: 999, unit: "ms", betterIsHigher: false)], score: 0.1, confidence: 0.2, freshness: 1.0)
        ])
        let runner = ProbeRunner(executor: executor, maxConcurrentProbes: 2, decisiveGap: 0.3, minimumConfidence: 0.8)

        let snapshot = await runner.run(subscription: config, sourceURL: config.sourceURL)
        let maxActiveTasks = await executor.maxActiveTasks()
        let completed = await executor.completedCandidateIDs()

        XCTAssertEqual(snapshot.sourceURL, config.sourceURL)
        XCTAssertEqual(snapshot.selectedCandidateID, "Fast")
        XCTAssertEqual(snapshot.bestCandidate?.candidateID, "Fast")
        XCTAssertLessThanOrEqual(maxActiveTasks, 2)
        XCTAssertLessThan(completed.count, 3)
    }
}

private actor ProbeExecutionStats {
    var active = 0
    var maxActive = 0
    var completedCandidateIDs: [String] = []
    var startedCandidateIDs: [String] = []
}

private final class StubProbeExecutor: ProbeExecuting, @unchecked Sendable {
    private let results: [String: ProbeCandidateResult]
    private let stats = ProbeExecutionStats()

    init(results: [String: ProbeCandidateResult]) {
        self.results = results
    }

    func maxActiveTasks() async -> Int {
        await stats.maxActive
    }

    func completedCandidateIDs() async -> [String] {
        await stats.completedCandidateIDs
    }

    func probe(_ candidate: ClashProxy) async -> ProbeCandidateResult {
        await stats.start(candidate.id)

        if candidate.name != "Fast" {
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        let result = results[candidate.name] ?? ProbeCandidateResult(
            candidateID: candidate.name,
            label: candidate.name,
            metrics: [],
            score: 0,
            confidence: 0,
            freshness: 0,
            isPartial: true
        )

        await stats.finish()
        await stats.recordCompletion(candidate.name)
        return result
    }
}

private extension ProbeExecutionStats {
    func start(_ candidateID: String) {
        active += 1
        maxActive = max(maxActive, active)
        startedCandidateIDs.append(candidateID)
    }

    func finish() {
        active = max(0, active - 1)
    }

    func recordCompletion(_ candidateID: String) {
        completedCandidateIDs.append(candidateID)
    }
}
