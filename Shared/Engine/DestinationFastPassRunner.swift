import Foundation

public enum RouteSwitchReason: String, Codable, Equatable, Sendable {
    case meaningfulGain
}

public enum RouteHoldReason: String, Codable, Equatable, Sendable {
    case pinnedRoute
    case insignificantGain
    case weakConfidence
    case staleEvidence
    case weakStability
    case noViableBetterCandidate
    case monitoringUnavailable
}

public enum RouteSwitchDecision: Equatable, Sendable {
    case switchRoute(RouteSwitchOutcome)
    case holdCurrent(RouteHoldOutcome)
}

public struct RouteSwitchOutcome: Equatable, Sendable {
    public let reason: RouteSwitchReason
    public let previousAssignment: DestinationRoutingAssignment?
    public let selectedCandidate: EvaluatedRouteCandidate
    public let runnerUpCandidate: EvaluatedRouteCandidate?

    public init(
        reason: RouteSwitchReason,
        previousAssignment: DestinationRoutingAssignment?,
        selectedCandidate: EvaluatedRouteCandidate,
        runnerUpCandidate: EvaluatedRouteCandidate?
    ) {
        self.reason = reason
        self.previousAssignment = previousAssignment
        self.selectedCandidate = selectedCandidate
        self.runnerUpCandidate = runnerUpCandidate
    }
}

public struct RouteHoldOutcome: Equatable, Sendable {
    public let reason: RouteHoldReason
    public let currentAssignment: DestinationRoutingAssignment?
    public let selectedCandidate: EvaluatedRouteCandidate?
    public let runnerUpCandidate: EvaluatedRouteCandidate?

    public init(
        reason: RouteHoldReason,
        currentAssignment: DestinationRoutingAssignment?,
        selectedCandidate: EvaluatedRouteCandidate?,
        runnerUpCandidate: EvaluatedRouteCandidate?
    ) {
        self.reason = reason
        self.currentAssignment = currentAssignment
        self.selectedCandidate = selectedCandidate
        self.runnerUpCandidate = runnerUpCandidate
    }
}

public struct RouteSwitchPolicy: Sendable {
    public var switchThresholdMS: Double
    public var minimumStability: Double
    public var minimumConfidence: Double
    public var staleFreshnessThreshold: Double

    public init(
        switchThresholdMS: Double = 8,
        minimumStability: Double = 0.62,
        minimumConfidence: Double = 0.65,
        staleFreshnessThreshold: Double = 0.5
    ) {
        self.switchThresholdMS = switchThresholdMS
        self.minimumStability = minimumStability
        self.minimumConfidence = minimumConfidence
        self.staleFreshnessThreshold = staleFreshnessThreshold
    }

    public func decide(
        currentAssignment: DestinationRoutingAssignment?,
        currentCandidate: EvaluatedRouteCandidate? = nil,
        bestCandidate: EvaluatedRouteCandidate?,
        runnerUpCandidate: EvaluatedRouteCandidate?,
        pinState: PinState,
        phase: AdaptiveRoutingPhase,
        monitoringAvailable: Bool
    ) -> RouteSwitchDecision {
        let selectedCurrentCandidate = currentCandidate ?? bestCandidate

        guard monitoringAvailable, let bestCandidate else {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .monitoringUnavailable,
                    currentAssignment: currentAssignment,
                    selectedCandidate: selectedCurrentCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        guard let currentAssignment else {
            return .switchRoute(
                RouteSwitchOutcome(
                    reason: .meaningfulGain,
                    previousAssignment: nil,
                    selectedCandidate: bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        if pinState.candidateID == currentAssignment.assignedProviderID {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .pinnedRoute,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        if bestCandidate.freshness < staleFreshnessThreshold {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .staleEvidence,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        if bestCandidate.confidence < minimumConfidence {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .weakConfidence,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        if bestCandidate.candidate.routeContext.providerID == currentAssignment.assignedProviderID, phase == .monitoring {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .noViableBetterCandidate,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        if (bestCandidate.stabilityScore ?? 0) < minimumStability {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .weakStability,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        let currentLatency = currentCandidate?.latencyMS ?? currentAssignment.measuredLatencyMS ?? runnerUpCandidate?.latencyMS
        let latencyGain = (currentLatency ?? bestCandidate.latencyMS ?? 0) - (bestCandidate.latencyMS ?? currentLatency ?? 0)
        if latencyGain < switchThresholdMS {
            return .holdCurrent(
                RouteHoldOutcome(
                    reason: .insignificantGain,
                    currentAssignment: currentAssignment,
                    selectedCandidate: currentCandidate ?? bestCandidate,
                    runnerUpCandidate: runnerUpCandidate
                )
            )
        }

        return .switchRoute(
            RouteSwitchOutcome(
                reason: .meaningfulGain,
                previousAssignment: currentAssignment,
                selectedCandidate: bestCandidate,
                runnerUpCandidate: runnerUpCandidate
            )
        )
    }
}

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
    public var routeSwitchPolicy: RouteSwitchPolicy
    public var routeCandidateEvaluator: any RouteCandidateEvaluating
    public var environmentResolver: any EnvironmentContextResolving

    public init(
        routeSwitchPolicy: RouteSwitchPolicy = RouteSwitchPolicy(),
        routeCandidateEvaluator: any RouteCandidateEvaluating = RouteCandidateEvaluator(),
        environmentResolver: any EnvironmentContextResolving = StaticEnvironmentContextResolver()
    ) {
        self.routeSwitchPolicy = routeSwitchPolicy
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
            let runnerUp = ranked.dropFirst().first
            let bestCandidate = evaluation.selectedCandidate ?? leading
            let currentCandidate = selectedHealth(for: previous, from: ranked)

            let source: AssignmentSource
            let status: DestinationAssignmentStatus
            let holdReason: RouteHoldReason?
            let switchReason: RouteSwitchReason?
            let summary: String
            let selected: EvaluatedRouteCandidate

            if previous == nil {
                selected = bestCandidate
                source = .initialDefault
                if evaluation.isDegraded {
                    status = .degraded
                    holdReason = .monitoringUnavailable
                    switchReason = nil
                    summary = evaluation.degradationReason ?? "Route evidence is too weak to select a healthy route."
                } else {
                    status = .monitoring
                    holdReason = nil
                    switchReason = nil
                    summary = "Monitoring \(destination.label) on \(selected.candidate.providerLabel) with the strongest current route health."
                }
            } else {
                let decision = routeSwitchPolicy.decide(
                    currentAssignment: previous,
                    currentCandidate: currentCandidate,
                    bestCandidate: bestCandidate,
                    runnerUpCandidate: runnerUp,
                    pinState: pinState,
                    phase: phase,
                    monitoringAvailable: evaluation.isDegraded == false
                )

                switch decision {
                case .switchRoute(let outcome):
                    selected = outcome.selectedCandidate
                    source = .automaticSelection
                    status = .switched
                    holdReason = nil
                    switchReason = outcome.reason
                    summary = switchSummary(
                        destinationLabel: destination.label,
                        selectedProviderLabel: outcome.selectedCandidate.candidate.providerLabel,
                        reason: outcome.reason
                    )
                case .holdCurrent(let outcome):
                    selected = outcome.selectedCandidate ?? currentCandidate ?? bestCandidate
                    switch outcome.reason {
                    case .pinnedRoute:
                        source = .manualOverride
                        status = .pinned
                    case .monitoringUnavailable:
                        source = previous?.source ?? .initialDefault
                        status = .degraded
                    default:
                        source = previous?.source ?? .initialDefault
                        status = .holding
                    }
                    holdReason = outcome.reason
                    switchReason = nil
                    summary = holdSummary(
                        destinationLabel: destination.label,
                        selectedProviderLabel: selected.candidate.providerLabel,
                        reason: outcome.reason,
                        degradationReason: evaluation.degradationReason
                    )
                }
            }

            let assignment = DestinationRoutingAssignment(
                routeContext: selected.candidate.routeContext,
                mode: .auto,
                assignedProviderLabel: selected.candidate.providerLabel,
                source: source,
                assignedAt: now.timeIntervalSince1970,
                freshness: selected.freshness,
                status: status,
                holdReason: holdReason,
                switchReason: switchReason,
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

    private func selectedHealth(
        for previous: DestinationRoutingAssignment?,
        from ranked: [EvaluatedRouteCandidate]
    ) -> EvaluatedRouteCandidate? {
        guard let previous else { return nil }
        return ranked.first(where: { $0.candidate.routeContext.providerID == previous.assignedProviderID })
    }

    private func switchSummary(
        destinationLabel: String,
        selectedProviderLabel: String,
        reason: RouteSwitchReason
    ) -> String {
        switch reason {
        case .meaningfulGain:
            return "Switched \(destinationLabel) to \(selectedProviderLabel) because the measured gain is now clearly meaningful."
        }
    }

    private func holdSummary(
        destinationLabel: String,
        selectedProviderLabel: String,
        reason: RouteHoldReason,
        degradationReason: String?
    ) -> String {
        switch reason {
        case .pinnedRoute:
            return "Pinned route remains active for \(destinationLabel)."
        case .insignificantGain:
            return "Holding \(destinationLabel) on \(selectedProviderLabel) because the measured gain is too small to justify a switch."
        case .weakConfidence:
            return "Holding \(destinationLabel) on \(selectedProviderLabel) until route confidence is stronger."
        case .staleEvidence:
            return "Holding \(destinationLabel) on \(selectedProviderLabel) because the evidence is getting stale."
        case .weakStability:
            return "Holding \(destinationLabel) on \(selectedProviderLabel) because route stability is still too weak."
        case .noViableBetterCandidate:
            return "Holding \(destinationLabel) on \(selectedProviderLabel) because no clearly better candidate is available."
        case .monitoringUnavailable:
            return degradationReason ?? "Monitoring for \(destinationLabel) is temporarily unavailable, so RockeRoom is holding the current route."
        }
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
