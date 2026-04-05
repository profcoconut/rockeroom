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
