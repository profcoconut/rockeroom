import Foundation

public enum AdaptiveRoutingPhase: String, Equatable, Sendable {
    case fastPass
    case monitoring
}

public protocol DestinationRoutingEvaluating: Sendable {
    func evaluate(
        subscription: SubscriptionConfig,
        sourceURL: URL,
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

    public init(
        switchThresholdMS: Double = 8,
        minimumStability: Double = 0.62
    ) {
        self.switchThresholdMS = switchThresholdMS
        self.minimumStability = minimumStability
    }

    public func evaluate(
        subscription: SubscriptionConfig,
        sourceURL: URL,
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

        for destination in destinations {
            let ranked = proxies
                .map { proxy in routeHealth(for: proxy, destination: destination, phase: phase, now: now) }
                .sorted { $0.score > $1.score }

            guard let best = ranked.first else { continue }
            let previous = previousAssignments?[destination.id]
            let runnerUp = ranked.dropFirst().first
            let current = selectedHealth(for: previous, from: ranked)

            let pinnedMatch = pinState.candidateID == previous?.assignedProviderID
            let shouldHoldCurrent = shouldHoldCurrentAssignment(
                previous: previous,
                current: current,
                best: best,
                runnerUp: runnerUp,
                pinnedMatch: pinnedMatch
            )

            let selected = shouldHoldCurrent ? current ?? best : best
            let source: AssignmentSource
            let status: DestinationAssignmentStatus
            let summary: String

            if pinnedMatch, previous != nil {
                source = .manualOverride
                status = .pinned
                summary = "Pinned route remains active for \(destination.label)."
            } else if let previous, previous.assignedProviderID == selected.proxy.id {
                source = previous.source
                status = .monitoring
                summary = "Monitoring \(destination.label) on \(selected.proxy.name) with the strongest current route health."
            } else if let previous, previous.assignedProviderID != selected.proxy.id {
                source = .automaticSelection
                status = .switched
                summary = "Switched \(destination.label) to \(selected.proxy.name) for lower latency and healthier routing."
            } else if shouldHoldCurrent {
                source = previous?.source ?? .initialDefault
                status = .holding
                summary = "Holding the current \(destination.label) route because the gain is too small or stability is weak."
            } else {
                source = previous == nil ? .initialDefault : .automaticSelection
                status = phase == .fastPass ? .monitoring : .switched
                summary = "Monitoring \(destination.label) on \(selected.proxy.name) with the strongest current route health."
            }

            let assignment = DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: .unknown,
                    destinationID: destination.id,
                    providerID: selected.proxy.id,
                    strategy: RoutingStrategy(legacyName: strategyName(for: destination, proxy: selected.proxy))
                ),
                mode: .auto,
                assignedProviderLabel: selected.proxy.name,
                source: source,
                assignedAt: now.timeIntervalSince1970,
                freshness: selected.freshness,
                status: status,
                measuredLatencyMS: selected.latencyMS,
                failureRate: selected.failureRate,
                stabilityScore: selected.stability,
                recentChangeSummary: summary,
                alternativeProviderID: runnerUp?.proxy.id,
                alternativeProviderLabel: runnerUp?.proxy.name
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
        current: DestinationProxyHealth?,
        best: DestinationProxyHealth,
        runnerUp: DestinationProxyHealth?,
        pinnedMatch: Bool
    ) -> Bool {
        guard let previous else { return false }
        if pinnedMatch { return true }
        if best.proxy.id == previous.assignedProviderID { return false }
        guard let current else { return false }

        let currentLatency = previous.measuredLatencyMS ?? current.latencyMS
        let latencyGain = currentLatency - best.latencyMS
        let stability = best.stability

        return latencyGain < switchThresholdMS || stability < minimumStability
    }

    private func selectedHealth(
        for previous: DestinationRoutingAssignment?,
        from ranked: [DestinationProxyHealth]
    ) -> DestinationProxyHealth? {
        guard let previous else { return nil }
        return ranked.first(where: { $0.proxy.id == previous.assignedProviderID })
    }

    private func strategyName(for destination: RoutingDestination, proxy: ClashProxy) -> String {
        if destination.isFallback {
            return "direct"
        }
        if proxy.name.lowercased().contains("stable") {
            return "fallback-proxy"
        }
        return "rule"
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

        let score = (220 - latencyMS) / 220
            + (1 - min(1, failureRate / 4))
            + stability

        return DestinationProxyHealth(
            proxy: proxy,
            latencyMS: latencyMS,
            failureRate: failureRate,
            stability: stability,
            freshness: freshness,
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
    let score: Double
}
