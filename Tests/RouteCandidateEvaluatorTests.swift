import XCTest

@testable import SharedKit

final class RouteCandidateEvaluatorTests: XCTestCase {
    func testRouteCandidateRepresentsDestinationEnvironmentProviderAndStrategyTogether() {
        let candidate = RouteCandidate(
            routeContext: RouteContext(
                environment: .wifiHome,
                destinationID: "openai",
                providerID: "hk-01",
                strategy: .fallbackProxy
            ),
            providerLabel: "Hong Kong 01"
        )

        XCTAssertEqual(candidate.routeContext.environment, .wifiHome)
        XCTAssertEqual(candidate.routeContext.destinationID, "openai")
        XCTAssertEqual(candidate.routeContext.providerID, "hk-01")
        XCTAssertEqual(candidate.routeContext.strategy, .fallbackProxy)
    }

    func testStaticEnvironmentResolverProvidesExplicitEnvironmentInput() {
        let resolver = StaticEnvironmentContextResolver(environment: .cellular)
        XCTAssertEqual(resolver.currentEnvironment(), .cellular)
    }

    func testEvaluatorDegradesWhenNoValidCandidatesRemainAfterNormalization() {
        let evaluator = RouteCandidateEvaluator()
        let candidates = [
            RouteCandidate(
                routeContext: RouteContext(
                    environment: .unknown,
                    destinationID: "openai",
                    providerID: "hk-01",
                    strategy: .custom("experimental")
                ),
                providerLabel: "Hong Kong 01"
            )
        ]
        let evidence = [
            ProbeCandidateResult(
                candidateID: "hk-01",
                label: "Hong Kong 01",
                metrics: [ProbeMetric(name: "Latency", value: 42, unit: "ms", betterIsHigher: false)],
                score: 0.9,
                confidence: 0.9,
                freshness: 0.95
            )
        ]

        let evaluation = evaluator.evaluate(candidates: candidates, evidence: evidence)

        XCTAssertTrue(evaluation.isDegraded)
        XCTAssertNil(evaluation.selectedCandidate)
        XCTAssertEqual(evaluation.rankedCandidates.count, 0)
    }

    func testEvaluatorCanChooseDifferentWinnersUnderDifferentEnvironments() {
        let evaluator = RouteCandidateEvaluator()
        let evidence = [
            ProbeCandidateResult(
                candidateID: "fast",
                label: "Fast Relay",
                metrics: [ProbeMetric(name: "Latency", value: 38, unit: "ms", betterIsHigher: false)],
                score: 0.86,
                confidence: 0.92,
                freshness: 0.95,
                failureRate: 0.2,
                stabilityScore: 0.78,
                reachabilityScore: 0.95
            ),
            ProbeCandidateResult(
                candidateID: "stable",
                label: "Stable Relay",
                metrics: [ProbeMetric(name: "Latency", value: 44, unit: "ms", betterIsHigher: false)],
                score: 0.83,
                confidence: 0.92,
                freshness: 0.95,
                failureRate: 0.1,
                stabilityScore: 0.88,
                reachabilityScore: 0.98
            )
        ]

        let cellularWinner = evaluator.evaluate(
            candidates: [
                RouteCandidate(
                    routeContext: RouteContext(
                        environment: .cellular,
                        destinationID: "openai",
                        providerID: "fast",
                        strategy: .direct
                    ),
                    providerLabel: "Fast Relay"
                ),
                RouteCandidate(
                    routeContext: RouteContext(
                        environment: .cellular,
                        destinationID: "openai",
                        providerID: "stable",
                        strategy: .fallbackProxy
                    ),
                    providerLabel: "Stable Relay"
                )
            ],
            evidence: evidence
        )

        let wifiWinner = evaluator.evaluate(
            candidates: [
                RouteCandidate(
                    routeContext: RouteContext(
                        environment: .wifiHome,
                        destinationID: "openai",
                        providerID: "fast",
                        strategy: .direct
                    ),
                    providerLabel: "Fast Relay"
                ),
                RouteCandidate(
                    routeContext: RouteContext(
                        environment: .wifiHome,
                        destinationID: "openai",
                        providerID: "stable",
                        strategy: .fallbackProxy
                    ),
                    providerLabel: "Stable Relay"
                )
            ],
            evidence: evidence
        )

        XCTAssertEqual(cellularWinner.selectedCandidate?.candidate.routeContext.providerID, "fast")
        XCTAssertEqual(wifiWinner.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    func testDestinationFastPassRunnerDelegatesCandidateComparisonToExplicitEvaluator() async {
        let selectedCandidate = EvaluatedRouteCandidate(
            candidate: RouteCandidate(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "stable",
                    strategy: .fallbackProxy
                ),
                providerLabel: "Stable Relay"
            ),
            score: 0.95,
            confidence: 0.91,
            freshness: 0.96,
            isPartial: false,
            latencyMS: 40,
            failureRate: 0.1,
            stabilityScore: 0.9,
            reachabilityScore: 0.98
        )
        let evaluator = StubRouteCandidateEvaluator(
            evaluation: RouteCandidateEvaluation(
                rankedCandidates: [
                    selectedCandidate,
                    EvaluatedRouteCandidate(
                        candidate: RouteCandidate(
                            routeContext: RouteContext(
                                environment: .wifiHome,
                                destinationID: "openai",
                                providerID: "fast",
                                strategy: .direct
                            ),
                            providerLabel: "Fast Relay"
                        ),
                        score: 0.7,
                        confidence: 0.91,
                        freshness: 0.96,
                        isPartial: false,
                        latencyMS: 52,
                        failureRate: 0.2,
                        stabilityScore: 0.7,
                        reachabilityScore: 0.9
                    )
                ],
                selectedCandidate: selectedCandidate
            )
        )
        let runner = DestinationFastPassRunner(
            routeCandidateEvaluator: evaluator,
            environmentResolver: StaticEnvironmentContextResolver(environment: .wifiHome)
        )
        let subscription = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            proxies: [
                ClashProxy(name: "Fast Relay", type: "ss"),
                ClashProxy(name: "Stable Relay", type: "vmess")
            ]
        )

        let assignments = await runner.evaluate(
            subscription: subscription,
            sourceURL: subscription.sourceURL,
            snapshot: nil,
            destinations: [RoutingDestination(slug: "openai", label: "OpenAI", ruleFamily: "ai", isFallback: false)],
            previousAssignments: nil,
            pinState: .none,
            phase: .fastPass,
            now: Date(timeIntervalSince1970: 1000)
        )

        XCTAssertEqual(assignments["openai"]?.assignedProviderID, "stable")
        XCTAssertEqual(assignments["openai"]?.routeContext.environment, .wifiHome)
        XCTAssertEqual(assignments["openai"]?.routeContext.strategy, .fallbackProxy)
    }

    func testDestinationFastPassRunnerKeepsPreviousAssignmentWhenHoldDecisionLacksCurrentProbe() async {
        let bestCandidate = EvaluatedRouteCandidate(
            candidate: RouteCandidate(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "fast",
                    strategy: .rule
                ),
                providerLabel: "Fast Relay"
            ),
            score: 0.88,
            confidence: 0.91,
            freshness: 0.4,
            isPartial: false,
            latencyMS: 36,
            failureRate: 0.2,
            stabilityScore: 0.86,
            reachabilityScore: 0.97
        )
        let evaluator = StubRouteCandidateEvaluator(
            evaluation: RouteCandidateEvaluation(
                rankedCandidates: [bestCandidate],
                selectedCandidate: bestCandidate
            )
        )
        let runner = DestinationFastPassRunner(
            routeSwitchPolicy: RouteSwitchPolicy(staleFreshnessThreshold: 0.5),
            routeCandidateEvaluator: evaluator,
            environmentResolver: StaticEnvironmentContextResolver(environment: .wifiHome)
        )
        let subscription = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            proxies: [ClashProxy(id: "fast", name: "Fast Relay", type: "ss")]
        )
        var previousAssignments = DestinationRoutingAssignments(
            sourceURL: subscription.sourceURL.absoluteString,
            selectedDestinationID: "openai"
        )
        previousAssignments.insert(
            DestinationRoutingAssignment(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "stable",
                    strategy: .fallbackProxy
                ),
                mode: .auto,
                assignedProviderLabel: "Stable Relay",
                source: .automaticSelection,
                assignedAt: 900,
                freshness: 0.92,
                status: .monitoring,
                measuredLatencyMS: 44,
                failureRate: 0.1,
                stabilityScore: 0.9,
                recentChangeSummary: "Monitoring OpenAI on Stable Relay."
            )
        )

        let assignments = await runner.evaluate(
            subscription: subscription,
            sourceURL: subscription.sourceURL,
            snapshot: nil,
            destinations: [RoutingDestination(slug: "openai", label: "OpenAI", ruleFamily: "ai", isFallback: false)],
            previousAssignments: previousAssignments,
            pinState: .none,
            phase: .monitoring,
            now: Date(timeIntervalSince1970: 1000)
        )

        XCTAssertEqual(assignments["openai"]?.assignedProviderID, "stable")
        XCTAssertEqual(assignments["openai"]?.assignedProviderLabel, "Stable Relay")
        XCTAssertEqual(assignments["openai"]?.status, .holding)
        XCTAssertEqual(assignments["openai"]?.holdReason, .staleEvidence)
        XCTAssertEqual(assignments["openai"]?.alternativeProviderID, "fast")
    }
}

final class RouteSwitchPolicyTests: XCTestCase {
    func testMeaningfullyBetterCandidateTriggersSwitchDecision() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 54, stabilityScore: 0.9)
        let bestCandidate = makeCandidate(providerID: "fast", latencyMS: 38, confidence: 0.91, freshness: 0.95, stabilityScore: 0.88)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            bestCandidate: bestCandidate,
            runnerUpCandidate: makeCandidate(providerID: "stable", latencyMS: 54, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: true
        )

        guard case .switchRoute(let outcome) = decision else {
            return XCTFail("Expected a switch decision.")
        }
        XCTAssertEqual(outcome.reason, .meaningfulGain)
        XCTAssertEqual(outcome.selectedCandidate.candidate.routeContext.providerID, "fast")
    }

    func testPinnedCurrentRouteProducesPinnedHoldDecision() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 54, stabilityScore: 0.9)
        let bestCandidate = makeCandidate(providerID: "fast", latencyMS: 38, confidence: 0.91, freshness: 0.95, stabilityScore: 0.88)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            currentCandidate: makeCandidate(providerID: "stable", latencyMS: 54, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            bestCandidate: bestCandidate,
            runnerUpCandidate: makeCandidate(providerID: "stable", latencyMS: 54, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            pinState: .pinned(candidateID: "stable"),
            phase: .monitoring,
            monitoringAvailable: true
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .pinnedRoute)
        XCTAssertEqual(outcome.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    func testMarginalGainWithWeakStabilityHoldsCurrentRoute() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 41, stabilityScore: 0.9)
        let bestCandidate = makeCandidate(providerID: "fast", latencyMS: 36, confidence: 0.91, freshness: 0.95, stabilityScore: 0.51)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            currentCandidate: makeCandidate(providerID: "stable", latencyMS: 41, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            bestCandidate: bestCandidate,
            runnerUpCandidate: makeCandidate(providerID: "stable", latencyMS: 41, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: true
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .weakStability)
        XCTAssertEqual(outcome.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    func testEqualOrNearEqualCandidatePreservesCurrentAssignment() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 44, stabilityScore: 0.9)
        let bestCandidate = makeCandidate(providerID: "fast", latencyMS: 39, confidence: 0.91, freshness: 0.95, stabilityScore: 0.88)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            currentCandidate: makeCandidate(providerID: "stable", latencyMS: 44, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            bestCandidate: bestCandidate,
            runnerUpCandidate: makeCandidate(providerID: "stable", latencyMS: 44, confidence: 0.9, freshness: 0.95, stabilityScore: 0.9),
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: true
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .insignificantGain)
        XCTAssertEqual(outcome.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    func testMissingEvidenceProducesMonitoringUnavailableHold() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 44, stabilityScore: 0.9)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            currentCandidate: makeCandidate(providerID: "stable", latencyMS: 44, confidence: 0.4, freshness: 0.3, stabilityScore: 0.9),
            bestCandidate: nil,
            runnerUpCandidate: nil,
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: false
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .monitoringUnavailable)
        XCTAssertEqual(outcome.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    func testMissingEvidenceWithoutCurrentCandidateLeavesSelectionUnsetForRunnerPreservation() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 44, stabilityScore: 0.9)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            bestCandidate: nil,
            runnerUpCandidate: nil,
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: false
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .monitoringUnavailable)
        XCTAssertNil(outcome.selectedCandidate)
    }

    func testSameProviderSelectionBecomesNoViableBetterCandidateHoldDuringMonitoring() {
        let policy = RouteSwitchPolicy()
        let currentAssignment = makeAssignment(providerID: "stable", latencyMS: 40, stabilityScore: 0.92)
        let bestCandidate = makeCandidate(providerID: "stable", latencyMS: 40, confidence: 0.93, freshness: 0.96, stabilityScore: 0.92)

        let decision = policy.decide(
            currentAssignment: currentAssignment,
            bestCandidate: bestCandidate,
            runnerUpCandidate: makeCandidate(providerID: "fast", latencyMS: 47, confidence: 0.9, freshness: 0.95, stabilityScore: 0.82),
            pinState: .none,
            phase: .monitoring,
            monitoringAvailable: true
        )

        guard case .holdCurrent(let outcome) = decision else {
            return XCTFail("Expected a hold decision.")
        }
        XCTAssertEqual(outcome.reason, .noViableBetterCandidate)
        XCTAssertEqual(outcome.selectedCandidate?.candidate.routeContext.providerID, "stable")
    }

    private func makeAssignment(
        providerID: String,
        latencyMS: Double,
        stabilityScore: Double
    ) -> DestinationRoutingAssignment {
        DestinationRoutingAssignment(
            routeContext: RouteContext(
                environment: .wifiHome,
                destinationID: "openai",
                providerID: providerID,
                strategy: .rule
            ),
            mode: .auto,
            assignedProviderLabel: providerID,
            source: .automaticSelection,
            assignedAt: 1000,
            freshness: 0.95,
            status: .monitoring,
            measuredLatencyMS: latencyMS,
            failureRate: 0.2,
            stabilityScore: stabilityScore,
            recentChangeSummary: "Monitoring route health."
        )
    }

    private func makeCandidate(
        providerID: String,
        latencyMS: Double,
        confidence: Double,
        freshness: Double,
        stabilityScore: Double
    ) -> EvaluatedRouteCandidate {
        EvaluatedRouteCandidate(
            candidate: RouteCandidate(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: providerID,
                    strategy: .rule
                ),
                providerLabel: providerID
            ),
            score: 0.9,
            confidence: confidence,
            freshness: freshness,
            isPartial: false,
            latencyMS: latencyMS,
            failureRate: 0.2,
            stabilityScore: stabilityScore,
            reachabilityScore: 0.95
        )
    }
}

final class DestinationFastPassRunnerFailurePreservationTests: XCTestCase {
    func testDegradedMonitoringPreservesPreviousAssignmentWhenCurrentProviderFallsOutOfRanking() async {
        let degradedBestCandidate = EvaluatedRouteCandidate(
            candidate: RouteCandidate(
                routeContext: RouteContext(
                    environment: .wifiHome,
                    destinationID: "openai",
                    providerID: "fast",
                    strategy: .direct
                ),
                providerLabel: "Fast Relay"
            ),
            score: 0.9,
            confidence: 0.4,
            freshness: 0.3,
            isPartial: false,
            latencyMS: 39,
            failureRate: 0.3,
            stabilityScore: 0.75,
            reachabilityScore: 0.9
        )
        let evaluator = StubRouteCandidateEvaluator(
            evaluation: RouteCandidateEvaluation(
                rankedCandidates: [degradedBestCandidate],
                selectedCandidate: nil,
                degradationReason: "Route evidence is too weak to claim a healthy best candidate."
            )
        )
        let runner = DestinationFastPassRunner(
            routeCandidateEvaluator: evaluator,
            environmentResolver: StaticEnvironmentContextResolver(environment: .wifiHome)
        )
        let subscription = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            proxies: [
                ClashProxy(name: "Fast Relay", type: "ss"),
                ClashProxy(name: "Stable Relay", type: "vmess")
            ]
        )
        var previousAssignments = DestinationRoutingAssignments(
            sourceURL: subscription.sourceURL.absoluteString,
            selectedDestinationID: "openai"
        )
        previousAssignments.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "stable",
                assignedProviderLabel: "Stable Relay",
                strategyName: "fallback-proxy",
                source: .automaticSelection,
                assignedAt: 1000,
                freshness: 0.92,
                status: .monitoring,
                measuredLatencyMS: 44,
                failureRate: 0.1,
                stabilityScore: 0.88,
                recentChangeSummary: "Monitoring OpenAI on Stable Relay."
            )
        )

        let assignments = await runner.evaluate(
            subscription: subscription,
            sourceURL: subscription.sourceURL,
            snapshot: nil,
            destinations: [RoutingDestination(slug: "openai", label: "OpenAI", ruleFamily: "ai", isFallback: false)],
            previousAssignments: previousAssignments,
            pinState: .none,
            phase: .monitoring,
            now: Date(timeIntervalSince1970: 2000)
        )

        XCTAssertEqual(assignments["openai"]?.assignedProviderID, "stable")
        XCTAssertEqual(assignments["openai"]?.assignedProviderLabel, "Stable Relay")
        XCTAssertEqual(assignments["openai"]?.status, .degraded)
        XCTAssertEqual(assignments["openai"]?.holdReason, .monitoringUnavailable)
        XCTAssertEqual(assignments["openai"]?.assignedAt, 1000)
    }

    func testNoRankedCandidatesPreservesPreviousAssignmentAsDegradedInsteadOfDroppingDestination() async {
        let evaluator = StubRouteCandidateEvaluator(
            evaluation: RouteCandidateEvaluation(
                rankedCandidates: [],
                selectedCandidate: nil,
                degradationReason: "No valid route candidates were available for evaluation."
            )
        )
        let runner = DestinationFastPassRunner(
            routeCandidateEvaluator: evaluator,
            environmentResolver: StaticEnvironmentContextResolver(environment: .wifiHome)
        )
        let subscription = SubscriptionConfig(
            sourceURL: URL(string: "https://example.com/sub")!,
            proxies: [ClashProxy(name: "Stable Relay", type: "vmess")]
        )
        var previousAssignments = DestinationRoutingAssignments(
            sourceURL: subscription.sourceURL.absoluteString,
            selectedDestinationID: "openai"
        )
        previousAssignments.insert(
            DestinationRoutingAssignment(
                destinationID: "openai",
                mode: .auto,
                assignedProviderID: "stable",
                assignedProviderLabel: "Stable Relay",
                strategyName: "fallback-proxy",
                source: .automaticSelection,
                assignedAt: 1000,
                freshness: 0.92,
                status: .monitoring,
                measuredLatencyMS: 44,
                failureRate: 0.1,
                stabilityScore: 0.88,
                recentChangeSummary: "Monitoring OpenAI on Stable Relay."
            )
        )

        let assignments = await runner.evaluate(
            subscription: subscription,
            sourceURL: subscription.sourceURL,
            snapshot: nil,
            destinations: [RoutingDestination(slug: "openai", label: "OpenAI", ruleFamily: "ai", isFallback: false)],
            previousAssignments: previousAssignments,
            pinState: .none,
            phase: .monitoring,
            now: Date(timeIntervalSince1970: 2000)
        )

        XCTAssertEqual(assignments.count, 1)
        XCTAssertEqual(assignments["openai"]?.assignedProviderID, "stable")
        XCTAssertEqual(assignments["openai"]?.status, .degraded)
        XCTAssertEqual(assignments["openai"]?.holdReason, .monitoringUnavailable)
        XCTAssertEqual(
            assignments["openai"]?.recentChangeSummary,
            "No valid route candidates were available for evaluation."
        )
    }
}

private final class StubRouteCandidateEvaluator: RouteCandidateEvaluating, @unchecked Sendable {
    let evaluation: RouteCandidateEvaluation

    init(evaluation: RouteCandidateEvaluation) {
        self.evaluation = evaluation
    }

    func evaluate(candidates: [RouteCandidate], evidence: [ProbeCandidateResult]) -> RouteCandidateEvaluation {
        evaluation
    }
}
