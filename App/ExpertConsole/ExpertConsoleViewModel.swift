import Foundation
import SharedKit

@MainActor
final class ExpertConsoleViewModel: ObservableObject {
    @Published var snapshot: ResultSnapshot?
    @Published var recommendationState: RecommendationState = .idle
    @Published var pinState: PinState = .none
    @Published var destinationAssignments: DestinationRoutingAssignments?
    @Published var monitoringStatusText: String = "Monitoring inactive"

    func refresh(
        snapshot: ResultSnapshot?,
        recommendationState: RecommendationState,
        pinState: PinState,
        destinationAssignments: DestinationRoutingAssignments?,
        monitoringStatusText: String
    ) {
        self.snapshot = snapshot
        self.recommendationState = recommendationState
        self.pinState = pinState
        self.destinationAssignments = destinationAssignments
        self.monitoringStatusText = monitoringStatusText
    }

    var routeContextSummary: RouteContextSummary? {
        guard let selectedAssignment else { return nil }
        return RouteContextSummary(
            title: "\(destinationLabel(for: selectedAssignment.destinationID)) via \(selectedAssignment.assignedProviderLabel)",
            statusBadge: controlState.badgeText,
            detailText: selectedAssignment.recentChangeSummary ?? "RockeRoom is monitoring the current route context."
        )
    }

    var routeContextRows: [RouteContextInspectorRow] {
        guard let selectedAssignment else { return [] }
        return [
            RouteContextInspectorRow(id: "destination", title: "Destination", value: destinationLabel(for: selectedAssignment.destinationID)),
            RouteContextInspectorRow(id: "environment", title: "Environment", value: environmentLabel(for: selectedAssignment.routeContext.environment)),
            RouteContextInspectorRow(id: "provider", title: "Provider", value: selectedAssignment.assignedProviderLabel),
            RouteContextInspectorRow(id: "strategy", title: "Strategy", value: strategyLabel(for: selectedAssignment.routeContext.strategy))
        ]
    }

    var destinationRows: [DestinationRow] {
        guard let destinationAssignments else { return [] }
        return destinationAssignments.all
            .sorted { lhs, rhs in
                if destinationAssignments.selectedDestinationID == lhs.destinationID { return true }
                if destinationAssignments.selectedDestinationID == rhs.destinationID { return false }
                return lhs.destinationID < rhs.destinationID
            }
            .map { assignment in
                DestinationRow(
                    id: assignment.destinationID,
                    title: RoutingDestination.v1Catalog.first(where: { $0.id == assignment.destinationID })?.label ?? assignment.destinationID,
                    provider: assignment.assignedProviderLabel,
                    strategy: assignment.strategyName,
                    statusText: statusText(for: assignment),
                    healthText: healthText(for: assignment),
                    detailText: assignment.recentChangeSummary ?? "Monitoring current route health.",
                    isPinned: isPinned(assignment)
                )
            }
    }

    var rankedCandidates: [CandidateRow] {
        guard let snapshot else { return [] }

        let recommendedID: String?
        if case .recommended(let summary) = recommendationState {
            recommendedID = summary.selectedCandidateID
        } else {
            recommendedID = snapshot.bestCandidate?.candidateID
        }

        return snapshot.candidates.enumerated().map { index, candidate in
            CandidateRow(
                id: candidate.consoleIdentifier,
                candidateID: candidate.candidateID,
                rank: index + 1,
                title: candidate.label,
                scoreText: String(format: "Score %.0f%%", candidate.score * 100),
                detailText: "\(confidence(candidate.confidence)) confidence, \(freshness(candidate.freshness))",
                isRecommended: candidate.candidateID == recommendedID,
                isPinned: candidate.candidateID == pinState.candidateID,
                isCurrent: candidate.candidateID == currentCandidate?.candidateID
            )
        }
    }

    var currentSetupText: String {
        currentCandidate?.label ?? "No measured setup yet"
    }

    var confidenceText: String {
        if let snapshot {
            return String(format: "%.0f%%", snapshot.overallConfidence * 100)
        }
        return "Pending"
    }

    var freshnessText: String {
        if let snapshot {
            return snapshot.freshness >= 0.85 ? "Just measured" : (snapshot.freshness >= 0.5 ? "Current" : "Stale")
        }
        return "Pending"
    }

    var evidenceRows: [(String, String)] {
        guard let currentCandidate else { return [] }
        return currentCandidate.metrics.map { metric in
            let rendered: String
            if metric.unit == "ms" {
                rendered = "\(Int(metric.value))\(metric.unit)"
            } else if metric.unit == "%" {
                rendered = String(format: "%.1f%@", metric.value, metric.unit)
            } else {
                rendered = "\(Int(metric.value.rounded())) \(metric.unit)"
            }
            return (metric.name, rendered)
        }
    }

    var controlText: String {
        pinState.candidateID == nil ? "Auto recommendation" : "Pinned"
    }

    var controlState: ControlStateRow {
        guard let selectedAssignment else {
            return ControlStateRow(
                badgeText: "Idle",
                title: "No active route context",
                detailText: "Run Benchmark from Home to populate adaptive routing state and route context.",
                actionText: nil
            )
        }

        if isPinned(selectedAssignment) {
            return ControlStateRow(
                badgeText: "Manual",
                title: "Pinned route active",
                detailText: "Manual control keeps \(selectedAssignment.assignedProviderLabel) active for \(destinationLabel(for: selectedAssignment.destinationID)).",
                actionText: "Alternatives remain visible for inspection, but RockeRoom will not switch until you unpin."
            )
        }

        switch selectedAssignment.status ?? .monitoring {
        case .monitoring:
            return ControlStateRow(
                badgeText: "Auto",
                title: "Auto-managing current route",
                detailText: monitoringStatusText,
                actionText: "RockeRoom will keep monitoring this destination and only move when the gain is clearly justified."
            )
        case .switched:
            return ControlStateRow(
                badgeText: "Auto",
                title: "Auto-switched recently",
                detailText: selectedAssignment.recentChangeSummary ?? "RockeRoom moved to a stronger route after a meaningful gain.",
                actionText: bestAlternative?.detailText
            )
        case .holding:
            return ControlStateRow(
                badgeText: "Holding",
                title: holdHeadline(for: selectedAssignment),
                detailText: selectedAssignment.recentChangeSummary ?? "RockeRoom is holding the current route until confidence improves.",
                actionText: bestAlternative?.detailText
            )
        case .pinned:
            return ControlStateRow(
                badgeText: "Manual",
                title: "Pinned route active",
                detailText: selectedAssignment.recentChangeSummary ?? "Manual control is active for the current destination.",
                actionText: "Alternatives remain visible for inspection, but RockeRoom will not switch until you unpin."
            )
        case .degraded:
            return ControlStateRow(
                badgeText: "Degraded",
                title: "Monitoring is limited",
                detailText: selectedAssignment.recentChangeSummary ?? "RockeRoom is holding the current route because monitoring is temporarily unavailable.",
                actionText: "Run Benchmark again when the route is measurable to restore confident switching."
            )
        }
    }

    var bestAlternative: AlternativeRouteRow? {
        guard let selectedAssignment, let alternativeLabel = selectedAssignment.alternativeProviderLabel else { return nil }

        let detail: String
        let inferredHoldReason = inferredHoldReason(for: selectedAssignment)

        if isPinned(selectedAssignment) {
            detail = "\(alternativeLabel) remains visible, but manual control keeps \(selectedAssignment.assignedProviderLabel) active."
        } else {
            switch inferredHoldReason {
            case .insignificantGain:
                detail = "\(alternativeLabel) is visible, but the measured gain is not yet large enough to justify a switch."
            case .weakConfidence:
                detail = "\(alternativeLabel) looks promising, but RockeRoom is waiting for stronger confidence."
            case .staleEvidence:
                detail = "\(alternativeLabel) is a candidate, but the evidence is stale and needs a refresh."
            case .weakStability:
                detail = "\(alternativeLabel) is reachable, but its route stability is still too weak."
            case .pinnedRoute:
                detail = "\(alternativeLabel) remains advisory only while the current route is pinned."
            case .monitoringUnavailable:
                detail = "\(alternativeLabel) is visible, but monitoring is too limited to trust an automatic change."
            case .noViableBetterCandidate:
                if selectedAssignment.status == .switched {
                    detail = "\(alternativeLabel) is the next best visible alternative if conditions change again."
                } else {
                    detail = "\(alternativeLabel) is the next best visible route if the current context weakens."
                }
            }
        }

        return AlternativeRouteRow(providerLabel: alternativeLabel, detailText: detail, badgeText: "Alternative")
    }

    var routeChangeHistoryRows: [RouteChangeHistoryRow] {
        guard let destinationAssignments else { return [] }
        return destinationAssignments.all
            .sorted { lhs, rhs in
                if lhs.destinationID == destinationAssignments.selectedDestinationID { return true }
                if rhs.destinationID == destinationAssignments.selectedDestinationID { return false }
                if lhs.assignedAt != rhs.assignedAt { return lhs.assignedAt > rhs.assignedAt }
                return lhs.destinationID < rhs.destinationID
            }
            .compactMap { assignment in
                guard let detail = assignment.recentChangeSummary else { return nil }
                return RouteChangeHistoryRow(
                    id: assignment.destinationID,
                    title: historyTitle(for: assignment),
                    detailText: detail,
                    badgeText: historyBadge(for: assignment),
                    isCurrent: assignment.destinationID == destinationAssignments.selectedDestinationID
                )
            }
    }

    var routeChangeHistoryEmptyText: String {
        "No recent route changes yet. Run Benchmark to seed current routing context and history."
    }

    var holdReasonText: String? {
        guard case .holding(let hold) = recommendationState else { return nil }

        switch hold.reason {
        case .pinned:
            return "Pinned provider active"
        case .lowConfidence:
            return "Holding for confidence"
        case .insignificantDelta:
            return "Holding for meaningful gain"
        case .staleData:
            return "Holding on stale evidence"
        case .noCandidates:
            return "No measurable candidates"
        }
    }

    private var currentCandidate: ProbeCandidateResult? {
        guard let snapshot else { return nil }

        if let pinnedID = pinState.candidateID {
            return snapshot.candidates.first(where: { $0.candidateID == pinnedID })
        }

        if case .recommended(let summary) = recommendationState {
            return snapshot.candidates.first(where: { $0.candidateID == summary.selectedCandidateID })
        }

        return snapshot.bestCandidate
    }

    private var selectedAssignment: DestinationRoutingAssignment? {
        if let destinationAssignments, let selectedAssignment = destinationAssignments.selectedAssignment {
            return selectedAssignment
        }
        return destinationAssignments?.all.sorted { $0.destinationID < $1.destinationID }.first
    }

    private func confidence(_ value: Double) -> String {
        switch value {
        case 0.85...:
            return "high"
        case 0.65...:
            return "medium"
        case 0.01...:
            return "low"
        default:
            return "pending"
        }
    }

    private func freshness(_ value: Double) -> String {
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
}

struct CandidateRow: Identifiable, Equatable {
    let id: String
    let candidateID: String
    let rank: Int
    let title: String
    let scoreText: String
    let detailText: String
    let isRecommended: Bool
    let isPinned: Bool
    let isCurrent: Bool
}

struct DestinationRow: Identifiable, Equatable {
    let id: String
    let title: String
    let provider: String
    let strategy: String
    let statusText: String
    let healthText: String
    let detailText: String
    let isPinned: Bool
}

struct RouteContextSummary: Equatable {
    let title: String
    let statusBadge: String
    let detailText: String
}

struct RouteContextInspectorRow: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct ControlStateRow: Equatable {
    let badgeText: String
    let title: String
    let detailText: String
    let actionText: String?
}

struct AlternativeRouteRow: Equatable {
    let providerLabel: String
    let detailText: String
    let badgeText: String
}

struct RouteChangeHistoryRow: Identifiable, Equatable {
    let id: String
    let title: String
    let detailText: String
    let badgeText: String
    let isCurrent: Bool
}

private extension ProbeCandidateResult {
    var consoleIdentifier: String {
        let lowered = label.lowercased()
        let sanitized = lowered.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "-"
        }
        let compacted = String(sanitized).replacingOccurrences(of: "--", with: "-")
        return compacted.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private extension ExpertConsoleViewModel {
    func statusText(for assignment: DestinationRoutingAssignment) -> String {
        if isPinned(assignment) {
            return "Pinned"
        }
        switch assignment.status ?? .monitoring {
        case .monitoring:
            return "Monitoring"
        case .switched:
            return "Auto-switched"
        case .holding:
            return "Holding"
        case .pinned:
            return "Pinned"
        case .degraded:
            return "Degraded"
        }
    }

    func healthText(for assignment: DestinationRoutingAssignment) -> String {
        let latency = assignment.measuredLatencyMS.map { "\(Int($0.rounded()))ms" } ?? "Latency n/a"
        let failures = assignment.failureRate.map { String(format: "%.1f%% fail", $0) } ?? "Failure n/a"
        return "\(latency) · \(failures)"
    }

    func isPinned(_ assignment: DestinationRoutingAssignment) -> Bool {
        if assignment.status == .pinned {
            return true
        }
        return pinState.candidateID == assignment.assignedProviderID
    }

    func destinationLabel(for destinationID: String) -> String {
        RoutingDestination.v1Catalog.first(where: { $0.id == destinationID })?.label ?? destinationID
    }

    func environmentLabel(for environment: NetworkEnvironment) -> String {
        switch environment {
        case .unknown:
            return "Unknown environment"
        case .wifiHome:
            return "Home Wi-Fi"
        case .wifiOther:
            return "Other Wi-Fi"
        case .cellular:
            return "Cellular"
        }
    }

    func strategyLabel(for strategy: RoutingStrategy) -> String {
        switch strategy {
        case .rule:
            return "Rule"
        case .direct:
            return "Direct"
        case .fallbackProxy:
            return "Fallback proxy"
        case .custom(let label):
            return label
        }
    }

    func holdHeadline(for assignment: DestinationRoutingAssignment) -> String {
        switch inferredHoldReason(for: assignment) {
        case .pinnedRoute:
            return "Holding because manual control wins"
        case .insignificantGain:
            return "Holding for meaningful gain"
        case .weakConfidence:
            return "Holding for stronger confidence"
        case .staleEvidence:
            return "Holding on stale evidence"
        case .weakStability:
            return "Holding for stronger stability"
        case .monitoringUnavailable:
            return "Holding because monitoring is limited"
        case .noViableBetterCandidate:
            return "Holding current route"
        }
    }

    func historyTitle(for assignment: DestinationRoutingAssignment) -> String {
        let destination = destinationLabel(for: assignment.destinationID)
        if isPinned(assignment) {
            return "\(destination) pinned to \(assignment.assignedProviderLabel)"
        }

        switch assignment.status ?? .monitoring {
        case .monitoring:
            return "\(destination) monitoring \(assignment.assignedProviderLabel)"
        case .switched:
            return "\(destination) switched to \(assignment.assignedProviderLabel)"
        case .holding:
            return "\(destination) holding on \(assignment.assignedProviderLabel)"
        case .pinned:
            return "\(destination) pinned to \(assignment.assignedProviderLabel)"
        case .degraded:
            return "\(destination) monitoring degraded"
        }
    }

    func historyBadge(for assignment: DestinationRoutingAssignment) -> String {
        if isPinned(assignment) {
            return "Manual"
        }
        switch assignment.status ?? .monitoring {
        case .monitoring:
            return "Monitoring"
        case .switched:
            return "Switched"
        case .holding:
            return "Holding"
        case .pinned:
            return "Manual"
        case .degraded:
            return "Degraded"
        }
    }

    func inferredHoldReason(for assignment: DestinationRoutingAssignment) -> InferredHoldReason {
        let summary = assignment.recentChangeSummary?.lowercased() ?? ""

        if isPinned(assignment) || summary.contains("pin") || summary.contains("manual") {
            return .pinnedRoute
        }
        if summary.contains("confidence") {
            return .weakConfidence
        }
        if summary.contains("stale") || summary.contains("refresh") {
            return .staleEvidence
        }
        if summary.contains("stability") || summary.contains("stable") {
            return .weakStability
        }
        if summary.contains("monitoring") && summary.contains("limited") {
            return .monitoringUnavailable
        }
        if summary.contains("gain") || summary.contains("small") {
            return .insignificantGain
        }
        return .noViableBetterCandidate
    }
}

private enum InferredHoldReason {
    case pinnedRoute
    case insignificantGain
    case weakConfidence
    case staleEvidence
    case weakStability
    case monitoringUnavailable
    case noViableBetterCandidate
}
