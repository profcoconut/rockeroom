import Foundation
import SharedKit

@MainActor
final class ExpertConsoleViewModel: ObservableObject {
    @Published var snapshot: ResultSnapshot?
    @Published var recommendationState: RecommendationState = .idle
    @Published var pinState: PinState = .none

    func refresh(snapshot: ResultSnapshot?, recommendationState: RecommendationState, pinState: PinState) {
        self.snapshot = snapshot
        self.recommendationState = recommendationState
        self.pinState = pinState
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
        snapshot?.bestCandidate?.label ?? "No measured setup yet"
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
            } else {
                rendered = "\(Int(metric.value.rounded()))\(metric.unit)"
            }
            return (metric.name.capitalized, rendered)
        }
    }

    var controlText: String {
        pinState.candidateID == nil ? "Auto mode" : "Pinned"
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
