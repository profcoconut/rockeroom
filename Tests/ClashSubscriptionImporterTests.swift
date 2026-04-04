import XCTest

@testable import SharedKit

final class ClashSubscriptionImporterTests: XCTestCase {
    func testImportSubscriptionAcceptsValidBase64Yaml() async {
        let yaml = """
        proxies:
          - name: US Proxy
            type: ss
            server: 1.2.3.4
            port: 8388
            udp: true
        """
        let data = Data(yaml.utf8).base64EncodedString().data(using: .utf8)!
        let fetcher = TestStubFetcher(data: data)
        let importer = ClashSubscriptionImporter(fetcher: fetcher, clock: { Date(timeIntervalSince1970: 1_700_000_000) })

        let result = await importer.importSubscription(from: "https://example.com/subscription")

        switch result {
        case .accepted(let config):
            XCTAssertEqual(config.sourceURL.absoluteString, "https://example.com/subscription")
            XCTAssertEqual(config.proxies.count, 1)
            XCTAssertEqual(config.proxies.first?.name, "US Proxy")
            XCTAssertEqual(config.proxies.first?.type, "ss")
            XCTAssertEqual(config.proxies.first?.server, "1.2.3.4")
            XCTAssertEqual(config.proxies.first?.port, 8388)
        case .rejected(let failure):
            XCTFail("Expected acceptance, got rejection: \(failure)")
        }
    }

    func testImportSubscriptionRejectsInvalidURL() async {
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data()))

        let result = await importer.importSubscription(from: "not a url")

        switch result {
        case .accepted:
            XCTFail("Expected rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, SubscriptionImportFailureReason.invalidURL)
        }
    }

    func testImportSubscriptionRejectsEmptyResponse() async {
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data()))

        let result = await importer.importSubscription(from: "https://example.com/subscription")

        switch result {
        case .accepted:
            XCTFail("Expected rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, SubscriptionImportFailureReason.emptyContent)
        }
    }

    func testImportSubscriptionRejectsMalformedContent() async {
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data("hello".utf8)))

        let result = await importer.importSubscription(from: "https://example.com/subscription")

        switch result {
        case .accepted:
            XCTFail("Expected rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, SubscriptionImportFailureReason.malformedContent)
            XCTAssertEqual(
                failure.message,
                "The subscription response is not valid Clash YAML or a supported share-link feed."
            )
        }
    }

    func testImportSubscriptionRejectsUnsupportedShareLinkFeed() async {
        let unsupportedFeed = """
        hysteria2://token@example.com:443?alpn=h3#Unsupported Hysteria
        """
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data(unsupportedFeed.utf8)))

        let result = await importer.importSubscription(from: "https://example.com/subscription")

        switch result {
        case .accepted:
            XCTFail("Expected rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, SubscriptionImportFailureReason.unsupportedContent)
            XCTAssertEqual(
                failure.message,
                "RockeRoom fetched the subscription, but this format is not supported yet."
            )
        }
    }

    func testImportSubscriptionRejectsUnreachableLinkAsRetryableFailure() async {
        let importer = ClashSubscriptionImporter(fetcher: TestThrowingFetcher())

        let result = await importer.importSubscription(from: "https://example.com/subscription")

        switch result {
        case .accepted:
            XCTFail("Expected rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, SubscriptionImportFailureReason.fetchFailed)
            XCTAssertTrue(failure.isRetryable)
        }
    }

}
