import XCTest

@testable import SharedKit

final class ClashSubscriptionImporterLiveFormatTests: XCTestCase {
    func testFixtureRepresentsUriFeedRatherThanClashYaml() throws {
        let fixtureText = try String(decoding: fixtureData(), as: UTF8.self)

        XCTAssertFalse(fixtureText.contains("proxies:"))
        XCTAssertTrue(fixtureText.contains("vless://"))
    }

    func testImporterAcceptsBase64VlessFeedAndBuildsProxyConfig() async throws {
        let encoded = try fixtureData().base64EncodedString()
        let importer = ClashSubscriptionImporter(
            fetcher: TestStubFetcher(data: Data(encoded.utf8)),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let result = await importer.importSubscription(from: "https://example.com/live-format")

        switch result {
        case .accepted(let config):
            XCTAssertEqual(config.sourceURL.absoluteString, "https://example.com/live-format")
            XCTAssertEqual(config.proxies.count, 3)
            XCTAssertEqual(config.proxies.first?.name, "🇭🇰 Hong Kong 01")
            XCTAssertEqual(config.proxies.first?.type, "vless")
            XCTAssertEqual(config.proxies.first?.server, "hk-gateway.example.com")
            XCTAssertEqual(config.proxies.first?.port, 35248)
            XCTAssertEqual(config.proxies.first?.metadata["security"], "reality")
            XCTAssertEqual(config.proxies.first?.metadata["sni"], "www.example.com")
            XCTAssertEqual(config.proxies.first?.metadata["credential"], "11111111-2222-3333-4444-555555555555")
            XCTAssertEqual(config.proxies.first?.metadata["flow"], "xtls-rprx-vision")
        case .rejected(let failure):
            XCTFail("Expected acceptance, got rejection: \(failure)")
        }
    }

    func testImporterIgnoresMetadataOnlyUriEntriesInFeed() async throws {
        let encoded = try fixtureData().base64EncodedString()
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data(encoded.utf8)))

        let result = await importer.importSubscription(from: "https://example.com/live-format")

        switch result {
        case .accepted(let config):
            XCTAssertFalse(config.proxies.contains(where: { $0.name.contains("剩余流量") }))
            XCTAssertFalse(config.proxies.contains(where: { $0.name.contains("套餐到期") }))
        case .rejected(let failure):
            XCTFail("Expected acceptance, got rejection: \(failure)")
        }
    }

    func testImporterRejectsMalformedSupportedUriFeed() async {
        let malformed = "vless://missing-host-and-port"
        let importer = ClashSubscriptionImporter(fetcher: TestStubFetcher(data: Data(malformed.utf8)))

        let result = await importer.importSubscription(from: "https://example.com/live-format")

        switch result {
        case .accepted:
            XCTFail("Expected malformed URI feed rejection")
        case .rejected(let failure):
            XCTAssertEqual(failure.reason, .malformedContent)
        }
    }

    private func fixtureData() throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/live-vless-subscription.txt")
        return try Data(contentsOf: url)
    }
}
