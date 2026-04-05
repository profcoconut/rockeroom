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

    public static let v1Catalog: [RoutingDestination] = [
        RoutingDestination(slug: "openai", label: "OpenAI", ruleFamily: "ai", isFallback: false),
        RoutingDestination(slug: "claude", label: "Claude", ruleFamily: "ai", isFallback: false),
        RoutingDestination(slug: "google-ai", label: "Google AI", ruleFamily: "ai", isFallback: false),
        RoutingDestination(slug: "netflix", label: "Netflix", ruleFamily: "streaming", isFallback: false),
        RoutingDestination(slug: "disney", label: "Disney+", ruleFamily: "streaming", isFallback: false),
        RoutingDestination(slug: "tiktok", label: "TikTok", ruleFamily: "social", isFallback: false),
        RoutingDestination(slug: "youtube", label: "YouTube", ruleFamily: "video", isFallback: false),
        RoutingDestination(slug: "telegram", label: "Telegram", ruleFamily: "messaging", isFallback: false),
        RoutingDestination(slug: "apple", label: "Apple", ruleFamily: "system", isFallback: false),
        RoutingDestination(slug: "final", label: "Final", ruleFamily: "direct", isFallback: true)
    ]
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

public enum DestinationAssignmentStatus: String, Codable, Equatable, Sendable {
    case monitoring
    case switched
    case holding
    case pinned
    case degraded
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
    public let routeContext: RouteContext
    public let mode: RoutingMode
    public let assignedProviderLabel: String

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
    public let status: DestinationAssignmentStatus?
    public let measuredLatencyMS: Double?
    public let failureRate: Double?
    public let stabilityScore: Double?
    public let recentChangeSummary: String?
    public let alternativeProviderID: String?
    public let alternativeProviderLabel: String?

    public var destinationID: String { routeContext.destinationID }
    public var assignedProviderID: String { routeContext.providerID }
    public var strategyName: String { routeContext.strategy.persistedLabel }

    public init(
        routeContext: RouteContext,
        mode: RoutingMode,
        assignedProviderLabel: String,
        source: AssignmentSource,
        assignedAt: TimeInterval,
        evidenceLinkSnapshotID: String? = nil,
        freshness: Double? = nil,
        status: DestinationAssignmentStatus? = nil,
        measuredLatencyMS: Double? = nil,
        failureRate: Double? = nil,
        stabilityScore: Double? = nil,
        recentChangeSummary: String? = nil,
        alternativeProviderID: String? = nil,
        alternativeProviderLabel: String? = nil
    ) {
        self.routeContext = routeContext
        self.mode = mode
        self.assignedProviderLabel = assignedProviderLabel
        self.source = source
        self.assignedAt = assignedAt
        self.evidenceLinkSnapshotID = evidenceLinkSnapshotID
        self.freshness = freshness
        self.status = status
        self.measuredLatencyMS = measuredLatencyMS
        self.failureRate = failureRate
        self.stabilityScore = stabilityScore
        self.recentChangeSummary = recentChangeSummary
        self.alternativeProviderID = alternativeProviderID
        self.alternativeProviderLabel = alternativeProviderLabel
    }

    public init(
        destinationID: String,
        mode: RoutingMode,
        assignedProviderID: String,
        assignedProviderLabel: String,
        strategyName: String,
        environment: NetworkEnvironment = .unknown,
        source: AssignmentSource,
        assignedAt: TimeInterval,
        evidenceLinkSnapshotID: String? = nil,
        freshness: Double? = nil,
        status: DestinationAssignmentStatus? = nil,
        measuredLatencyMS: Double? = nil,
        failureRate: Double? = nil,
        stabilityScore: Double? = nil,
        recentChangeSummary: String? = nil,
        alternativeProviderID: String? = nil,
        alternativeProviderLabel: String? = nil
    ) {
        self.init(
            routeContext: RouteContext(
                environment: environment,
                destinationID: destinationID,
                providerID: assignedProviderID,
                strategy: RoutingStrategy(legacyName: strategyName)
            ),
            mode: mode,
            assignedProviderLabel: assignedProviderLabel,
            source: source,
            assignedAt: assignedAt,
            evidenceLinkSnapshotID: evidenceLinkSnapshotID,
            freshness: freshness,
            status: status,
            measuredLatencyMS: measuredLatencyMS,
            failureRate: failureRate,
            stabilityScore: stabilityScore,
            recentChangeSummary: recentChangeSummary,
            alternativeProviderID: alternativeProviderID,
            alternativeProviderLabel: alternativeProviderLabel
        )
    }

    private enum CodingKeys: String, CodingKey {
        case routeContext
        case mode
        case assignedProviderLabel
        case source
        case assignedAt
        case evidenceLinkSnapshotID
        case freshness
        case status
        case measuredLatencyMS
        case failureRate
        case stabilityScore
        case recentChangeSummary
        case alternativeProviderID
        case alternativeProviderLabel

        // Legacy flat payload keys.
        case destinationID
        case assignedProviderID
        case strategyName
        case environment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let routeContext = try container.decodeIfPresent(RouteContext.self, forKey: .routeContext) {
            self.routeContext = routeContext
        } else {
            self.routeContext = RouteContext(
                environment: try container.decodeIfPresent(NetworkEnvironment.self, forKey: .environment) ?? .unknown,
                destinationID: try container.decode(String.self, forKey: .destinationID),
                providerID: try container.decode(String.self, forKey: .assignedProviderID),
                strategy: RoutingStrategy(
                    legacyName: try container.decode(String.self, forKey: .strategyName)
                )
            )
        }
        mode = try container.decode(RoutingMode.self, forKey: .mode)
        assignedProviderLabel = try container.decode(String.self, forKey: .assignedProviderLabel)
        source = try container.decode(AssignmentSource.self, forKey: .source)
        assignedAt = try container.decode(TimeInterval.self, forKey: .assignedAt)
        evidenceLinkSnapshotID = try container.decodeIfPresent(String.self, forKey: .evidenceLinkSnapshotID)
        freshness = try container.decodeIfPresent(Double.self, forKey: .freshness)
        status = try container.decodeIfPresent(DestinationAssignmentStatus.self, forKey: .status)
        measuredLatencyMS = try container.decodeIfPresent(Double.self, forKey: .measuredLatencyMS)
        failureRate = try container.decodeIfPresent(Double.self, forKey: .failureRate)
        stabilityScore = try container.decodeIfPresent(Double.self, forKey: .stabilityScore)
        recentChangeSummary = try container.decodeIfPresent(String.self, forKey: .recentChangeSummary)
        alternativeProviderID = try container.decodeIfPresent(String.self, forKey: .alternativeProviderID)
        alternativeProviderLabel = try container.decodeIfPresent(String.self, forKey: .alternativeProviderLabel)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(routeContext, forKey: .routeContext)
        try container.encode(mode, forKey: .mode)
        try container.encode(assignedProviderLabel, forKey: .assignedProviderLabel)
        try container.encode(source, forKey: .source)
        try container.encode(assignedAt, forKey: .assignedAt)
        try container.encodeIfPresent(evidenceLinkSnapshotID, forKey: .evidenceLinkSnapshotID)
        try container.encodeIfPresent(freshness, forKey: .freshness)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(measuredLatencyMS, forKey: .measuredLatencyMS)
        try container.encodeIfPresent(failureRate, forKey: .failureRate)
        try container.encodeIfPresent(stabilityScore, forKey: .stabilityScore)
        try container.encodeIfPresent(recentChangeSummary, forKey: .recentChangeSummary)
        try container.encodeIfPresent(alternativeProviderID, forKey: .alternativeProviderID)
        try container.encodeIfPresent(alternativeProviderLabel, forKey: .alternativeProviderLabel)
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
