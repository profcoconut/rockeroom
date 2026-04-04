import Foundation

public enum RefreshTrigger: Equatable, Sendable {
    case restore
    case foreground
    case explicit
}

public enum RefreshEvidenceState: Equatable, Sendable {
    case missing
    case current
    case staleUsable
    case staleHold
}

public enum RefreshAvailability: Equatable, Sendable {
    case unavailable
    case explicitOnly
    case recommended
}

public struct RefreshAssessment: Equatable, Sendable {
    public var snapshot: ResultSnapshot?
    public var evidenceState: RefreshEvidenceState
    public var refreshAvailability: RefreshAvailability

    public init(
        snapshot: ResultSnapshot?,
        evidenceState: RefreshEvidenceState,
        refreshAvailability: RefreshAvailability
    ) {
        self.snapshot = snapshot
        self.evidenceState = evidenceState
        self.refreshAvailability = refreshAvailability
    }
}

public struct RefreshCoordinator: Sendable {
    public var currentWindow: TimeInterval
    public var staleWindow: TimeInterval
    public var staleFreshnessThreshold: Double

    public init(
        currentWindow: TimeInterval = 5 * 60,
        staleWindow: TimeInterval = 30 * 60,
        staleFreshnessThreshold: Double = 0.5
    ) {
        self.currentWindow = currentWindow
        self.staleWindow = max(staleWindow, currentWindow + 1)
        self.staleFreshnessThreshold = staleFreshnessThreshold
    }

    public func evaluate(
        snapshot: ResultSnapshot?,
        tunnelStatus: ClashAdapterStatus,
        trigger: RefreshTrigger,
        now: Date = .init()
    ) -> RefreshAssessment {
        guard var snapshot else {
            return RefreshAssessment(
                snapshot: nil,
                evidenceState: .missing,
                refreshAvailability: .unavailable
            )
        }

        snapshot.freshness = min(snapshot.freshness, freshnessForAge(of: snapshot, now: now))

        if snapshot.freshness >= staleFreshnessThreshold {
            return RefreshAssessment(
                snapshot: snapshot,
                evidenceState: .current,
                refreshAvailability: .unavailable
            )
        }

        switch tunnelStatus.state {
        case .running, .starting:
            return RefreshAssessment(
                snapshot: snapshot,
                evidenceState: .staleUsable,
                refreshAvailability: trigger == .explicit ? .unavailable : .recommended
            )
        case .stopped, .failed:
            return RefreshAssessment(
                snapshot: snapshot,
                evidenceState: .staleHold,
                refreshAvailability: .explicitOnly
            )
        }
    }

    private func freshnessForAge(of snapshot: ResultSnapshot, now: Date) -> Double {
        let age = max(0, now.timeIntervalSince(snapshot.generatedAt))
        guard age > currentWindow else { return 1.0 }
        guard age < staleWindow else { return 0.0 }

        let decayRange = staleWindow - currentWindow
        let elapsed = age - currentWindow
        return max(0, 1.0 - (elapsed / decayRange))
    }
}
