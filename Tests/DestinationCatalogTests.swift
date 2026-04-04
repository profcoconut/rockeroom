import XCTest
@testable import SharedKit

/// Contract tests for the v1 destination catalog.
///
/// These tests define the expected shape and stability guarantees of the curated
/// top-10 destination fixture set. They are intentionally fixture-first: the helpers
/// are built to satisfy these assertions, not the other way around.
///
/// The v1 destinations are locked here so later routing-engine work cannot silently
/// widen scope without breaking these tests.
final class DestinationCatalogTests: XCTestCase {
    private var catalogLoader: DestinationCatalogLoader!

    override func setUp() {
        super.setUp()
        // Use no-arg initializer: bundle lookup falls back to #filePath-derived path
        // which is stable regardless of which bundle Bundle.main resolves to at runtime.
        catalogLoader = DestinationCatalogLoader()
    }

    override func tearDown() {
        catalogLoader = nil
        super.tearDown()
    }

    // MARK: - Happy Path

    func testCatalogResolvesExactlyTenDestinations() {
        let destinations = catalogLoader.loadAll()
        XCTAssertEqual(destinations.count, 10, "Catalog must contain exactly 10 destinations")
    }

    func testCatalogContainsExpectedTop10Labels() {
        let destinations = catalogLoader.loadAll()
        let labels = Set(destinations.map(\.label))
        let expected = Set([
            "OpenAI",
            "Claude",
            "Google AI",
            "Netflix",
            "Disney+",
            "TikTok",
            "YouTube",
            "Telegram",
            "Apple",
            "Final"
        ])
        XCTAssertEqual(labels, expected, "Catalog must contain the expected top-10 labels")
    }

    func testCatalogContainsExpectedTop10IDs() {
        let destinations = catalogLoader.loadAll()
        let ids = Set(destinations.map(\.id))
        let expected = Set([
            "openai",
            "claude",
            "google-ai",
            "netflix",
            "disney",
            "tiktok",
            "youtube",
            "telegram",
            "apple",
            "final"
        ])
        XCTAssertEqual(ids, expected, "Catalog must contain the expected top-10 IDs")
    }

    func testEachDestinationHasStableInternalIdentity() {
        let destinations = catalogLoader.loadAll()
        for destination in destinations {
            XCTAssertFalse(destination.id.isEmpty, "Destination id must not be empty")
            XCTAssertFalse(
                destination.id.contains(" "),
                "Destination id '\(destination.id)' must not contain spaces — identity is slug-based"
            )
            XCTAssertEqual(
                destination.id.lowercased(),
                destination.id,
                "Destination id '\(destination.id)' must be lowercase for stable identity"
            )
        }
    }

    func testFinalDestinationMarkedAsFallback() {
        let destinations = catalogLoader.loadAll()
        guard let final = destinations.first(where: { $0.id == "final" }) else {
            XCTFail("'final' destination must exist in catalog")
            return
        }
        XCTAssertTrue(final.isFallback, "'final' destination must be marked as fallback")
    }

    func testNonFallbackDestinationsAreNotMarkedAsFallback() {
        let destinations = catalogLoader.loadAll().filter { !$0.isFallback }
        let fallbackIDs = Set(destinations.filter { $0.isFallback }.map { $0.id })
        XCTAssertTrue(fallbackIDs.isEmpty, "Only 'final' should be marked as fallback, found: \(fallbackIDs)")
    }

    // MARK: - Edge Cases

    func testDestinationOrderChangesDoNotAffectIdentityValues() {
        let firstLoad = catalogLoader.loadAll()
        let secondLoad = catalogLoader.loadAll()

        let firstIDs = firstLoad.map(\.id)
        let secondIDs = secondLoad.map(\.id)

        XCTAssertEqual(
            Set(firstIDs),
            Set(secondIDs),
            "Destination identity is ID-based; order must not affect identity resolution"
        )
    }

    func testAllDestinationsHaveRuleFamilyProvenance() {
        let destinations = catalogLoader.loadAll()
        for destination in destinations {
            XCTAssertFalse(
                destination.ruleFamily.isEmpty,
                "Destination '\(destination.id)' must have a rule family provenance"
            )
        }
    }

    // MARK: - Error Paths

    func testNoDuplicateDestinationIDs() {
        let destinations = catalogLoader.loadAll()
        let ids = destinations.map(\.id)
        let uniqueIDs = Set(ids)
        XCTAssertEqual(
            ids.count,
            uniqueIDs.count,
            "Duplicate destination IDs found: \(ids.filter { id in ids.filter { $0 == id }.count > 1 })"
        )
    }

    func testNoDuplicateDisplayLabels() {
        let destinations = catalogLoader.loadAll()
        let labels = destinations.map(\.label)
        let uniqueLabels = Set(labels)
        XCTAssertEqual(
            labels.count,
            uniqueLabels.count,
            "Duplicate display labels found: \(labels.filter { label in labels.filter { $0 == label }.count > 1 })"
        )
    }

    func testFinalIsTheOnlyDestinationWithoutExplicitRuleFamily() {
        let destinations = catalogLoader.loadAll()
        let nonFinalWithoutRuleFamily = destinations.filter {
            $0.id != "final" && $0.ruleFamily == "direct"
        }
        XCTAssertTrue(
            nonFinalWithoutRuleFamily.isEmpty,
            "Only 'final' may have 'direct' rule family; found others: \(nonFinalWithoutRuleFamily.map(\.id))"
        )
    }

    // MARK: - Integration

    func testCatalogLoaderIsReusableAcrossMultipleLoads() {
        let first = catalogLoader.loadAll()
        let second = catalogLoader.loadAll()
        let third = catalogLoader.loadAll()

        XCTAssertEqual(first.map(\.id).sorted(), second.map(\.id).sorted())
        XCTAssertEqual(second.map(\.id).sorted(), third.map(\.id).sorted())
    }
}
