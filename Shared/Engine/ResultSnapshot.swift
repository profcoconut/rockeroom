import Foundation

public struct ProbeMetric: Equatable, Sendable, Codable, Identifiable {
    public var id: String { name }
    public var name: String
    public var value: Double
    public var unit: String
    public var betterIsHigher: Bool

    public init(name: String, value: Double, unit: String, betterIsHigher: Bool) {
        self.name = name
        self.value = value
        self.unit = unit
        self.betterIsHigher = betterIsHigher
    }
}

public struct ProbeCandidateResult: Equatable, Sendable, Codable, Identifiable {
    public var id: String { candidateID }
    public var candidateID: String
    public var label: String
    public var metrics: [ProbeMetric]
    public var score: Double
    public var confidence: Double
    public var freshness: Double
    public var isPartial: Bool

    public init(
        candidateID: String,
        label: String,
        metrics: [ProbeMetric],
        score: Double,
        confidence: Double,
        freshness: Double,
        isPartial: Bool = false
    ) {
        self.candidateID = candidateID
        self.label = label
        self.metrics = metrics
        self.score = score
        self.confidence = confidence
        self.freshness = freshness
        self.isPartial = isPartial
    }
}

public struct ResultSnapshot: Equatable, Sendable, Codable {
    public var sourceURL: URL
    public var generatedAt: Date
    public var candidates: [ProbeCandidateResult]
    public var selectedCandidateID: String?
    public var overallConfidence: Double
    public var freshness: Double
    public var isPartial: Bool

    public init(
        sourceURL: URL,
        generatedAt: Date = .init(),
        candidates: [ProbeCandidateResult],
        selectedCandidateID: String? = nil,
        overallConfidence: Double,
        freshness: Double,
        isPartial: Bool
    ) {
        self.sourceURL = sourceURL
        self.generatedAt = generatedAt
        self.candidates = candidates
        self.selectedCandidateID = selectedCandidateID
        self.overallConfidence = overallConfidence
        self.freshness = freshness
        self.isPartial = isPartial
    }

    public var bestCandidate: ProbeCandidateResult? {
        candidates.sorted(by: { $0.score > $1.score }).first
    }

    public var runnerUpCandidate: ProbeCandidateResult? {
        let ordered = candidates.sorted(by: { $0.score > $1.score })
        return ordered.dropFirst().first
    }
}
