import Foundation

public struct ProofPayload: Equatable, Sendable, Codable {
    public var title: String
    public var subtitle: String?
    public var deltas: [ProofDelta]
    public var confidence: Double
    public var freshness: Double
    public var isPartial: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        deltas: [ProofDelta],
        confidence: Double,
        freshness: Double,
        isPartial: Bool
    ) {
        self.title = title
        self.subtitle = subtitle
        self.deltas = deltas
        self.confidence = confidence
        self.freshness = freshness
        self.isPartial = isPartial
    }
}

public struct ProofDelta: Equatable, Sendable, Codable, Identifiable {
    public var id: String { metricName }
    public var metricName: String
    public var currentValue: Double
    public var candidateValue: Double
    public var unit: String
    public var betterIsHigher: Bool
    public var note: String?

    public init(
        metricName: String,
        currentValue: Double,
        candidateValue: Double,
        unit: String,
        betterIsHigher: Bool,
        note: String? = nil
    ) {
        self.metricName = metricName
        self.currentValue = currentValue
        self.candidateValue = candidateValue
        self.unit = unit
        self.betterIsHigher = betterIsHigher
        self.note = note
    }

    public var delta: Double { candidateValue - currentValue }
    public var isImprovement: Bool {
        betterIsHigher ? candidateValue >= currentValue : candidateValue <= currentValue
    }
}
