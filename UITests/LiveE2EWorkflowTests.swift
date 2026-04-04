import XCTest

final class LiveE2EWorkflowTests: XCTestCase {
    @MainActor
    func testScenarioDrivenLiveImportBenchmarkAndConsoleFlow() throws {
        let app = configuredApp(
            storageSuite: "ui-live-e2e-console",
            scenario: "expert-console",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )

        app.launch()

        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Ranked candidates"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pin ")).firstMatch.waitForExistence(timeout: 8)
        )
    }

    @MainActor
    func testScenarioDrivenPinUnpinReturnsToHomeRecommendation() throws {
        let app = configuredApp(
            storageSuite: "ui-live-e2e-pin-unpin",
            scenario: "pin-unpin-home",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )

        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertTrue(app.buttons["benchmarkButton"].exists)
        XCTAssertFalse(app.staticTexts["Manual selection is active. Unpin it from Expert Console to return to automatic recommendation."].exists)
    }

    @MainActor
    func testScenarioDrivenTunnelFailureStopsOnRecoverableHomeState() throws {
        let app = configuredApp(
            storageSuite: "ui-live-e2e-tunnel-failure",
            scenario: "tunnel-failure",
            resetStorage: true,
            demoTunnelFailure: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )

        app.launch()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Could not start the RockeRoom tunnel."].waitForExistence(timeout: 8))
    }

    @MainActor
    func testScenarioDrivenStaleHintThenRefreshFlow() throws {
        let suite = "ui-live-e2e-stale-refresh"
        let firstPass = configuredApp(
            storageSuite: suite,
            scenario: "benchmark-home",
            resetStorage: true,
            nowUnix: 100,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        firstPass.launch()

        XCTAssertTrue(
            firstPass.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
        firstPass.terminate()

        let staleHint = configuredApp(
            storageSuite: suite,
            scenario: "stale-hint",
            resetStorage: false,
            nowUnix: 2_000,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        staleHint.launch()

        XCTAssertTrue(staleHint.staticTexts["refreshHintText"].waitForExistence(timeout: 8))
        staleHint.terminate()

        let refreshed = configuredApp(
            storageSuite: suite,
            scenario: "stale-refresh",
            resetStorage: false,
            nowUnix: 2_000,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        refreshed.launch()

        XCTAssertTrue(
            refreshed.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertFalse(refreshed.staticTexts["refreshHintText"].exists)
    }

    @MainActor
    private func configuredApp(
        storageSuite: String,
        scenario: String,
        resetStorage: Bool,
        nowUnix: Int? = nil,
        demoTunnelFailure: Bool = false,
        demoSubscriptionPayloadB64: String
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ROCKEROOM_STORAGE_SUITE"] = storageSuite
        app.launchEnvironment["ROCKEROOM_RESET_STORAGE"] = resetStorage ? "1" : "0"
        app.launchEnvironment["ROCKEROOM_USE_DEMO_FETCHER"] = "1"
        app.launchEnvironment["ROCKEROOM_USE_DEMO_TUNNEL"] = "1"
        app.launchEnvironment["ROCKEROOM_LIVE_E2E_SCENARIO"] = scenario
        app.launchEnvironment["ROCKEROOM_LIVE_E2E_LINK"] = "https://example.com/live-e2e"
        app.launchEnvironment["ROCKEROOM_DEMO_SUBSCRIPTION_PAYLOAD_B64"] = demoSubscriptionPayloadB64
        if let nowUnix {
            app.launchEnvironment["ROCKEROOM_NOW_UNIX"] = String(nowUnix)
        }
        if demoTunnelFailure {
            app.launchEnvironment["ROCKEROOM_DEMO_TUNNEL_FAILURE"] = "1"
        }
        return app
    }

    private func liveSubscriptionPayloadBase64() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Tests/Fixtures/live-vless-subscription.txt")
        let data = try Data(contentsOf: url)
        return data.base64EncodedString()
    }
}
