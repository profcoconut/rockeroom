import Foundation

public enum AdaptiveRoutingPhase: String, Equatable, Sendable {
    case fastPass
    case monitoring
}

public protocol DestinationRoutingEvaluating: Sendable {
    func evaluate(
        subscription: SubscriptionConfig,
        sourceURL: URL,
        snapshot: ResultSnapshot?,
        destinations: [RoutingDestination],
        previousAssignments: DestinationRoutingAssignments?,
        pinState: PinState,
        phase: AdaptiveRoutingPhase,
        now: Date
    ) async -> DestinationRoutingAssignments
}

public struct DestinationFastPassRunner: DestinationRoutingEvaluating {
    public var switchThresholdMS: Double
    public var minimumStability: Double
    public var routeCandidateEvaluator: any RouteCandidateEvaluating
    public var environmentResolver: any EnvironmentContextResolving

    public init(
        switchThresholdMS: Double = 8,
        minimumStability: Double = 0.62,
        routeCandidateEvaluator: any RouteCandidateEvaluating = RouteCandidateEvaluator(),
        environmentResolver: any EnvironmentContextResolving = StaticEnvironmentContextResolver()
    ) {
        self.switchThresholdMS = switchThresholdMS
        self.minimumStability = minimumStability
        self.routeCandidateEvaluator = routeCandidateEvaluator
        self.environmentResolver = environmentResolver
    }

    public func evaluate(
        subscription: SubscriptionConfig,
        sourceURL: URL,
        snapshot: ResultSnapshot? = nil,
        destinations: [RoutingDestination],
        previousAssignments: DestinationRoutingAssignments?,
        pinState: PinState,
        phase: AdaptiveRoutingPhase,
        now: Date
    ) async -> DestinationRoutingAssignments {
        var assignments = DestinationRoutingAssignments(
            sourceURL: sourceURL.absoluteString,
            selectedDestinationID: previousAssignments?.selectedDestinationID ?? destinations.first?.id
        )

        let proxies = subscription.proxies
        guard !proxies.isEmpty else { return assignments }
        let environment = environmentResolver.currentEnvironment()

        for destination in destinations {
            let routeCandidates = buildRouteCandidates(
                destination: destination,
                proxies: proxies,
                environment: environment
            )
            let evidence = buildProbeEvidence(
                from: snapshot,
                proxies: proxies,
                destination: destination,
                phase: phase,
                now: now
            )
            let evaluation = routeCandidateEvaluator.evaluate(
                candidates: routeCandidates,
                evidence: evidence
            )
            let ranked = evaluation.rankedCandidates
            guard let leading = ranked.first else { continue }
            let previous = previousAssignments?[destination.id]
            let selectedCandidate = evaluation.selectedCandidate ?? leading
            let runnerUp = ranked.dropFirst().first

            let pinnedMatch = pinState.candidateID == previous?.assignedProviderID
            let shouldHoldCurrent = shouldHoldCurrentAssignment(
                previous: previous,
                best: selectedCandidate,
                runnerUp: runnerUp,
                pinnedMatch: pinnedMatch
            )

            let selected = shouldHoldCurrent ? selectedHealth(for: previous, from: ranked) ?? selectedCandidate : selectedCandidate
            let source: AssignmentSource
            let status: DestinationAssignmentStatus
            let summary: String

            if pinnedMatch, previous != nil {
                source = .manualOverride
                status = .pinned
                summary = "Pinned route remains active for \(destination.label)."
            } else if evaluation.isDegraded {
                source = previous?.source ?? .initialDefault
                status = .degraded
                summary = evaluation.degradationReason ?? "Route evidence is too weak to select a healthy route."
            } else if let previous, previous.assignedProviderID != selected.candidate.routeContext.providerID {
                source = .automaticSelection
                status = .switched
                summary = "Switched \(destination.label) to \(selected.candidate.providerLabel) for lower latency and healthier routing."
            } else if shouldHoldCurrent {
                source = previous?.source ?? .initialDefault
                status = .holding
                summary = "Holding the current \(destination.label) route because the gain is too small or stability is weak."
            } else {
                source = previous == nil ? .initialDefault : .automaticSelection
                status = phase == .fastPass ? .monitoring : .switched
                summary = "Monitoring \(destination.label) on \(selected.candidate.providerLabel) with the strongest current route health."
            }

            let assignment = DestinationRoutingAssignment(
                routeContext: selected.candidate.routeContext,
                mode: .auto,
                assignedProviderLabel: selected.candidate.providerLabel,
                source: source,
                assignedAt: now.timeIntervalSince1970,
                freshness: selected.freshness,
                status: status,
                measuredLatencyMS: selected.latencyMS,
                failureRate: selected.failureRate,
                stabilityScore: selected.stabilityScore,
                recentChangeSummary: summary,
                alternativeProviderID: runnerUp?.candidate.routeContext.providerID,
                alternativeProviderLabel: runnerUp?.candidate.providerLabel
            )
            assignments.insert(assignment)
        }

        if assignments.selectedDestinationID == nil {
            assignments.selectedDestinationID = assignments.all.first?.destinationID
        }

        return assignments
    }

    private func shouldHoldCurrentAssignment(
        previous: DestinationRoutingAssignment?,
        best: EvaluatedRouteCandidate,
        runnerUp: EvaluatedRouteCandidate?,
        pinnedMatch: Bool
    ) -> Bool {
        guard let previous else { return false }
        if pinnedMatch { return true }
        if best.candidate.routeContext.providerID == previous.assignedProviderID { return false }

        let bestLatency = best.latencyMS ?? 999
        let currentLatency = previous.measuredLatencyMS ?? (runnerUp?.latencyMS ?? bestLatency)
        let latencyGain = currentLatency - bestLatency
        let stability = best.stabilityScore ?? 0

        return latencyGain < switchThresholdMS || stability < minimumStability
    }

    private func selectedHealth(
        for previous: DestinationRoutingAssignment?,
        from ranked: [EvaluatedRouteCandidate]
    ) -> EvaluatedRouteCandidate? {
        guard let previous else { return nil }
        return ranked.first(where: { $0.candidate.routeContext.providerID == previous.assignedProviderID })
    }

    private func buildRouteCandidates(
        destination: RoutingDestination,
        proxies: [ClashProxy],
        environment: NetworkEnvironment
    ) -> [RouteCandidate] {
        proxies.flatMap { proxy in
            supportedStrategies(for: destination, proxy: proxy).map { strategy in
                RouteCandidate(
                    routeContext: RouteContext(
                        environment: environment,
                        destinationID: destination.id,
                        providerID: proxy.id,
                        strategy: strategy
                    ),
                    providerLabel: proxy.name
                )
            }
        }
    }

    private func supportedStrategies(for destination: RoutingDestination, proxy: ClashProxy) -> [RoutingStrategy] {
        if destination.isFallback {
            return [.direct]
        }
        if proxy.name.lowercased().contains("stable") {
            return [.rule, .fallbackProxy]
        }
        return [.rule, .direct]
    }

    private func buildProbeEvidence(
        from snapshot: ResultSnapshot?,
        proxies: [ClashProxy],
        destination: RoutingDestination,
        phase: AdaptiveRoutingPhase,
        now: Date
    ) -> [ProbeCandidateResult] {
        if let snapshot, snapshot.candidates.isEmpty == false {
            return snapshot.candidates
        }

        return proxies.map { proxy in
            let health = routeHealth(for: proxy, destination: destination, phase: phase, now: now)
            return ProbeCandidateResult(
                candidateID: proxy.id,
                label: proxy.name,
                metrics: [
                    ProbeMetric(name: "Latency", value: health.latencyMS, unit: "ms", betterIsHigher: false),
                    ProbeMetric(name: "Failure Rate", value: health.failureRate, unit: "%", betterIsHigher: false),
                    ProbeMetric(name: "Reachability", value: health.reachabilityScore * 100, unit: "%", betterIsHigher: true)
                ],
                score: health.score,
                confidence: health.confidence,
                freshness: health.freshness,
                failureRate: health.failureRate,
                stabilityScore: health.stability,
                reachabilityScore: health.reachabilityScore
            )
        }
    }

    private func routeHealth(
        for proxy: ClashProxy,
        destination: RoutingDestination,
        phase: AdaptiveRoutingPhase,
        now: Date
    ) -> DestinationProxyHealth {
        let seed = stableSeed("\(proxy.id)|\(proxy.name)|\(destination.id)")
        let cycle = phase == .monitoring ? Int(now.timeIntervalSince1970 / 10) % 7 : 0
        let latencyBias = Double((seed + cycle * 7) % 55)
        let failureBias = Double((seed + cycle * 5) % 18) / 10
        let stabilityBias = Double((seed + cycle * 3) % 25) / 100

        let latencyMS = 34 + latencyBias
        let failureRate = 0.1 + failureBias
        let stability = max(0.45, 0.95 - stabilityBias)
        let freshness = phase == .fastPass ? 0.97 : 0.9
        let confidence = phase == .fastPass ? 0.9 : 0.82
        let reachabilityScore = max(0.5, 1 - (failureRate / 5))

        let score = (220 - latencyMS) / 220
            + (1 - min(1, failureRate / 4))
            + stability

        return DestinationProxyHealth(
            proxy: proxy,
            latencyMS: latencyMS,
            failureRate: failureRate,
            stability: stability,
            freshness: freshness,
            confidence: confidence,
            reachabilityScore: reachabilityScore,
            score: score
        )
    }

    private func stableSeed(_ value: String) -> Int {
        value.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + Int(scalar.value)
        }
    }
}

private struct DestinationProxyHealth {
    let proxy: ClashProxy
    let latencyMS: Double
    let failureRate: Double
    let stability: Double
    let freshness: Double
    let confidence: Double
    let reachabilityScore: Double
    let score: Double
}
