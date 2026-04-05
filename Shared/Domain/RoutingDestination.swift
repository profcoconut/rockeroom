import Foundation

/// A curated destination in the v1 routing catalog.
///
/// Destinations represent the top-10 traffic categories RockeRoom can route to.
/// Each has a stable internal identity (slug), display label, rule-family provenance,
/// and fallback semantics when upstream data is incomplete.
///
/// Identity stability is enforced: the `id` is lowercase, space-free, and does not
/// depend on the current display label formatting.
public struct RoutingDestination: Equatable, Sendable, Codable, Identifiable {
    public var id: String { slug }
    public let slug: String
    public let label: String
    public let ruleFamily: String
    public let isFallback: Bool

    public init(slug: String, label: String, ruleFamily: String, isFallback: Bool) {
        self.slug = slug
        self.label = label
        self.ruleFamily = ruleFamily
        self.isFallback = isFallback
    }
}

// MARK: - Routing Mode

/// The control mode for destination routing.
///
/// - `auto`: RockeRoom may auto-apply better routes when evidence is strong.
///   Manual overrides are suppressed while auto mode is active.
/// - `manual`: RockeRoom only advises. User must confirm before any route change.
public enum RoutingMode: String, Codable, Equatable, Sendable {
    case auto
    case manual
}

// MARK: - Assignment Source

/// Describes how the current route assignment was determined.
public enum AssignmentSource: String, Codable, Equatable, Sendable {
    /// The route was selected automatically by the routing policy.
    case automaticSelection
    /// The route was manually chosen or overridden by the user.
    case manualOverride
    /// The route is the initial default before any measurement has occurred.
    case initialDefault
}

// MARK: - Destination Routing Assignment

/// A durable record of the current routing assignment for one destination.
///
/// This is the production counterpart to the Sprint 1 test-only `RoutingState` contract.
/// It stores the routing truth that `Home`, `Expert Console`, and later optimization
/// code read from shared persistence.
///
/// Measurement evidence (metrics, confidence, freshness) lives in `ResultSnapshot`,
/// not here. This struct carries only assignment identity, mode, and provenance.
public struct DestinationRoutingAssignment: Codable, Equatable, Sendable {
    public let destinationID: String
    public let mode: RoutingMode
    public let assignedProviderID: String
    public let assignedProviderLabel: String

    /// The routing strategy name (e.g., "rule", "direct", "proxy").
    /// The exact set of valid strategy names is determined by the Clash configuration.
    public let strategyName: String

    /// How this assignment was determined.
    public let source: AssignmentSource

    /// When this assignment was made, in Unix time.
    public let assignedAt: TimeInterval

    /// Optional reference to the `ResultSnapshot.id` that provided the evidence
    /// for this assignment. If set, the snapshot can be used to backfill metrics
    /// for the destination's current quality display.
    public let evidenceLinkSnapshotID: String?

    /// Snapshot freshness at the time of assignment (0.0–1.0, 1.0 = fresh).
    /// If `evidenceLinkSnapshotID` is set, this field preserves the freshness
    /// context even if the linked snapshot has since been superseded.
    public let freshness: Double?

    public init(
        destinationID: String,
        mode: RoutingMode,
        assignedProviderID: String,
        assignedProviderLabel: String,
        strategyName: String,
        source: AssignmentSource,
        assignedAt: TimeInterval,
        evidenceLinkSnapshotID: String? = nil,
        freshness: Double? = nil
    ) {
        self.destinationID = destinationID
        self.mode = mode
        self.assignedProviderID = assignedProviderID
        self.assignedProviderLabel = assignedProviderLabel
        self.strategyName = strategyName
        self.source = source
        self.assignedAt = assignedAt
        self.evidenceLinkSnapshotID = evidenceLinkSnapshotID
        self.freshness = freshness
    }
}

// MARK: - Destination Routing Assignments Container

/// A collection of per-destination routing assignments with one selected active destination.
///
/// This is the payload stored by `DestinationRoutingAssignmentStore`. It holds
/// assignments for zero or more destinations and tracks which one is currently
/// active (`selectedDestinationID`).
///
/// All destinations share the same `sourceURL` (the subscription link) so assignments
/// remain coherent with the `ResultSnapshot` that informed them.
public struct DestinationRoutingAssignments: Codable, Equatable, Sendable {
    /// The subscription link these assignments are associated with.
    public var sourceURL: String?

    /// The currently selected active destination. Null if no destination is selected yet.
    public var selectedDestinationID: String?

    private var byDestinationID: [String: DestinationRoutingAssignment]

    public var isEmpty: Bool { byDestinationID.isEmpty }
    public var count: Int { byDestinationID.count }

    public init(
        sourceURL: String? = nil,
        selectedDestinationID: String? = nil,
        byDestinationID: [String: DestinationRoutingAssignment] = [:]
    ) {
        self.sourceURL = sourceURL
        self.selectedDestinationID = selectedDestinationID
        self.byDestinationID = byDestinationID
    }

    /// Returns the assignment for a given destination, or nil if none exists.
    public subscript(destinationID: String) -> DestinationRoutingAssignment? {
        get { byDestinationID[destinationID] }
        set {
            if let newValue = newValue {
                byDestinationID[destinationID] = newValue
            } else {
                byDestinationID.removeValue(forKey: destinationID)
            }
        }
    }

    /// The currently active assignment. Nil if no destination is selected or
    /// the selected destination has no assignment.
    public var selectedAssignment: DestinationRoutingAssignment? {
        guard let selectedDestinationID else { return nil }
        return byDestinationID[selectedDestinationID]
    }

    /// Inserts or replaces an assignment for a destination.
    public mutating func insert(_ assignment: DestinationRoutingAssignment) {
        byDestinationID[assignment.destinationID] = assignment
    }

    /// Removes all assignments and clears the selected destination.
    public mutating func clear() {
        byDestinationID.removeAll()
        selectedDestinationID = nil
    }

    /// All assignments as an unordered array.
    public var all: [DestinationRoutingAssignment] {
        Array(byDestinationID.values)
    }
}
