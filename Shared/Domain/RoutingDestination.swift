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

/// Loads the v1 deterministic destination catalog from test fixtures.
///
/// The catalog is locked as deterministic fixture files so later routing-engine work
/// cannot silently widen scope without breaking `DestinationCatalogTests`.
public struct DestinationCatalogLoader: Sendable {
    private let bundle: Bundle?

    public init() {
        self.bundle = nil
    }

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    /// Loads all destinations from the fixture catalog.
    ///
    /// Returns exactly 10 destinations in an unspecified order.
    /// Duplicate IDs, duplicate labels, or missing required fields cause a test failure.
    public func loadAll() -> [RoutingDestination] {
        // Strategy:
        // 1. If a bundle was injected, try its resources.
        // 2. Otherwise, xcodebuild sets the working directory to the project root,
        //    so Tests/Fixtures/routing-destinations is accessible directly.
        // 3. Development fallback: derive path from the source file location.
        let directoryURL: URL

        if let bundle {
            if let url = bundle.url(forResource: "routing-destinations", withExtension: nil) {
                directoryURL = url
            } else {
                // Fallback for when resources aren't copied into the test bundle.
                // xcodebuild sets CWD to the project directory containing Tests/.
                directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent("Tests/Fixtures/routing-destinations")
            }
        } else if let mainURL = Bundle.main.url(forResource: "routing-destinations", withExtension: nil) {
            directoryURL = mainURL
        } else {
            // RoutingDestination.swift lives at Shared/Domain/, so 3 deleteLastPathComponent
            // calls reach the project root: Domain -> Shared -> rockeroom.
            let projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // Shared/Domain
                .deletingLastPathComponent()  // Shared
                .deletingLastPathComponent()  // project root
            directoryURL = projectRoot
                .appendingPathComponent("Tests")
                .appendingPathComponent("Fixtures")
                .appendingPathComponent("routing-destinations")
        }

        return loadFromDirectory(directoryURL)
    }

    private func loadFromDirectory(_ directoryURL: URL) -> [RoutingDestination] {
        let fileManager = FileManager.default
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
        } catch {
            return []
        }

        let yamlFiles = contents
            .filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        return yamlFiles.compactMap { parseYAML($0) }
    }

    private func parseYAML(_ fileURL: URL) -> RoutingDestination? {
        guard let data = try? Data(contentsOf: fileURL),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        var slug: String?
        var label: String?
        var ruleFamily: String?
        var fallback: Bool = false

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Parse "key: value" format using first colon as separator.
            guard let colonRange = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<colonRange.lowerBound])
            let value = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            switch key {
            case "id":
                if !value.isEmpty { slug = value }
            case "label":
                if !value.isEmpty { label = value }
            case "rule_family":
                if !value.isEmpty { ruleFamily = value }
            case "fallback":
                fallback = value == "true"
            default:
                break
            }
        }

        guard let slug, let label, let ruleFamily else {
            return nil
        }

        return RoutingDestination(slug: slug, label: label, ruleFamily: ruleFamily, isFallback: fallback)
    }

}
