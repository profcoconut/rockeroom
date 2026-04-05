import Foundation

public protocol ProbeExecuting: Sendable {
    func probe(_ candidate: ClashProxy) async -> ProbeCandidateResult
}

public final class ProbeRunner: Sendable {
    private let executor: any ProbeExecuting
    private let maxConcurrentProbes: Int
    private let decisiveGap: Double
    private let minimumConfidence: Double

    public init(
        executor: any ProbeExecuting,
        maxConcurrentProbes: Int = 3,
        decisiveGap: Double = 0.12,
        minimumConfidence: Double = 0.65
    ) {
        self.executor = executor
        self.maxConcurrentProbes = max(1, maxConcurrentProbes)
        self.decisiveGap = decisiveGap
        self.minimumConfidence = minimumConfidence
    }

    public func run(
        subscription: SubscriptionConfig,
        sourceURL: URL,
        now: Date = .init()
    ) async -> ResultSnapshot {
        let candidates = subscription.proxies
        guard !candidates.isEmpty else {
            return ResultSnapshot(
                sourceURL: sourceURL,
                generatedAt: now,
                candidates: [],
                selectedCandidateID: nil,
                overallConfidence: 0,
                freshness: 0,
                isPartial: true
            )
        }

        let results = await probeCandidates(candidates).map(Self.normalize)
        let orderedResults = results.sorted(by: Self.sortsAhead)
        let selectedCandidateID = orderedResults.first?.candidateID
        let overallConfidence = results.map(\.confidence).max() ?? 0
        let freshness = results.map(\.freshness).min() ?? 0
        let isPartial = results.contains(where: \.isPartial)

        return ResultSnapshot(
            sourceURL: sourceURL,
            generatedAt: now,
            candidates: orderedResults,
            selectedCandidateID: selectedCandidateID,
            overallConfidence: overallConfidence,
            freshness: freshness,
            isPartial: isPartial
        )
    }

    private func probeCandidates(_ candidates: [ClashProxy]) async -> [ProbeCandidateResult] {
        await withTaskGroup(of: ProbeCandidateResult.self) { group in
            var pending = candidates.makeIterator()
            var results: [ProbeCandidateResult] = []
            var inFlight = 0

            func enqueueNext() {
                guard let candidate = pending.next() else { return }
                inFlight += 1
                group.addTask { [executor] in await executor.probe(candidate) }
            }

            for _ in 0..<maxConcurrentProbes {
                enqueueNext()
            }

            while let result = await group.next() {
                inFlight = max(0, inFlight - 1)
                results.append(result)

                if Self.shouldStopEarly(
                    results: results,
                    totalCandidates: candidates.count,
                    decisiveGap: decisiveGap,
                    minimumConfidence: minimumConfidence
                ) {
                    group.cancelAll()
                    break
                }

                let minimumObservedCandidates = min(2, candidates.count)
                let startedCandidates = results.count + inFlight

                if results.count < minimumObservedCandidates {
                    if startedCandidates < minimumObservedCandidates {
                        enqueueNext()
                    }
                    continue
                }

                while inFlight < maxConcurrentProbes {
                    let priorInFlight = inFlight
                    enqueueNext()
                    if inFlight == priorInFlight {
                        break
                    }
                }
            }

            return results
        }
    }

    private static func shouldStopEarly(
        results: [ProbeCandidateResult],
        totalCandidates: Int,
        decisiveGap: Double,
        minimumConfidence: Double
    ) -> Bool {
        guard totalCandidates > 1, results.count >= 1 else { return false }
        let ordered = results.sorted(by: { $0.score > $1.score })
        guard let best = ordered.first else { return false }
        guard best.confidence >= minimumConfidence else { return false }
        guard let runnerUp = ordered.dropFirst().first else { return false }
        return (best.score - runnerUp.score) >= decisiveGap
    }

    private static func normalize(_ result: ProbeCandidateResult) -> ProbeCandidateResult {
        var normalized = result
        if normalized.reachabilityScore == nil {
            normalized.reachabilityScore = normalized.isPartial ? 0.5 : 1.0
        }
        if normalized.stabilityScore == nil {
            normalized.stabilityScore = normalized.score
        }
        return normalized
    }

    private static func sortsAhead(_ lhs: ProbeCandidateResult, _ rhs: ProbeCandidateResult) -> Bool {
        if lhs.score == rhs.score {
            return lhs.confidence > rhs.confidence
        }
        return lhs.score > rhs.score
    }
}
