import XCTest

final class FirstRunOptimizeFlowTests: XCTestCase {
    @MainActor
    func testFirstRunLaunchesToFocusedSetupScreen() {
        let app = configuredApp(storageSuite: "ui-first-run-setup", resetStorage: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["Add your subscription"].exists)
        XCTAssertTrue(app.textFields["subscriptionLinkField"].exists)
        XCTAssertTrue(app.buttons["importSubscriptionButton"].exists)
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)
    }

    @MainActor
    func testBase64VlessSubscriptionImportsThroughSetupScreen() throws {
        let app = configuredApp(
            storageSuite: "ui-live-format-import",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        app.launch()

        let field = app.textFields["subscriptionLinkField"]
        field.tap()
        field.typeText("https://example.com/live-format")
        app.buttons["importSubscriptionButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Imported Clash subscription"].exists)

        app.buttons["benchmarkButton"].tap()

        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH %@", "Current setup: 🇭🇰 Hong Kong 01")
            ).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testClashSubscriptionImportBenchmarkAndRestoreFlow() {
        let suite = "ui-first-run-benchmark-restore"
        let app = configuredApp(storageSuite: suite, resetStorage: true)
        app.launch()

        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["benchmarkButton"].exists)

        app.buttons["benchmarkButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Measured recommendation"].exists)
        XCTAssertTrue(app.staticTexts["Latency"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Expert Console"].tap()
        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: 5))

        app.terminate()

        let relaunched = configuredApp(storageSuite: suite, resetStorage: false)
        relaunched.launch()

        XCTAssertTrue(relaunched.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            relaunched.staticTexts["Recommended setup"].exists ||
            relaunched.staticTexts["Best current setup"].exists
        )
        XCTAssertTrue(
            relaunched.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testInvalidSubscriptionCanRecoverWithoutLeavingSetupFlow() {
        let app = configuredApp(storageSuite: "ui-setup-recovery", resetStorage: true)
        app.launch()

        app.buttons["useInvalidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        XCTAssertTrue(app.staticTexts["Could not load the Clash subscription link."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["Home"].exists)

        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["benchmarkButton"].exists)
    }

    @MainActor
    func testMarketplaceTabIsPlaceholder() {
        let app = configuredApp(storageSuite: "ui-marketplace-placeholder", resetStorage: true)
        app.launch()

        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        XCTAssertTrue(app.tabBars.buttons["Marketplace"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Marketplace"].tap()

        XCTAssertTrue(app.navigationBars["Marketplace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["This tab is a placeholder in v1. RockeRoom’s core loop is import, benchmark, inspect, and control."].exists)
    }

    @MainActor
    func testStaleRestoreCanRefreshCurrentEvidence() {
        let suite = "ui-stale-restore-refresh"
        let app = configuredApp(storageSuite: suite, resetStorage: true, nowUnix: 100)
        app.launch()

        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()
        app.buttons["benchmarkButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))

        app.terminate()

        let relaunched = configuredApp(storageSuite: suite, resetStorage: false, nowUnix: 2000)
        relaunched.launch()

        XCTAssertTrue(relaunched.staticTexts["refreshHintText"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.staticTexts["Best current setup"].exists)

        relaunched.buttons["benchmarkButton"].tap()

        XCTAssertTrue(relaunched.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
        XCTAssertFalse(relaunched.staticTexts["refreshHintText"].exists)
    }

    @MainActor
    func testTunnelStartFailureCanRecoverOnRelaunch() {
        let suite = "ui-tunnel-start-failure-recovery"
        let failing = configuredApp(
            storageSuite: suite,
            resetStorage: true,
            demoTunnelFailure: true
        )
        failing.launch()

        failing.buttons["useValidDemoLinkButton"].tap()
        failing.buttons["importSubscriptionButton"].tap()
        failing.buttons["benchmarkButton"].tap()

        XCTAssertTrue(failing.staticTexts["Could not start the RockeRoom tunnel."].waitForExistence(timeout: 5))
        XCTAssertTrue(
            failing.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.exists
        )

        failing.terminate()

        let recovered = configuredApp(storageSuite: suite, resetStorage: false)
        recovered.launch()

        XCTAssertTrue(
            recovered.staticTexts["Could not start the RockeRoom tunnel."].waitForExistence(timeout: 5) ||
            recovered.staticTexts["Benchmark unavailable"].exists
        )
        recovered.buttons["benchmarkButton"].tap()

        XCTAssertTrue(recovered.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(recovered.staticTexts["Tunnel: running"].exists)
    }

    @MainActor
    private func configuredApp(
        storageSuite: String,
        resetStorage: Bool,
        nowUnix: Int? = nil,
        demoTunnelFailure: Bool = false,
        demoSubscriptionPayloadB64: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ROCKEROOM_STORAGE_SUITE"] = storageSuite
        app.launchEnvironment["ROCKEROOM_USE_DEMO_FETCHER"] = "1"
        app.launchEnvironment["ROCKEROOM_USE_DEMO_TUNNEL"] = "1"
        app.launchEnvironment["ROCKEROOM_SHOW_TEST_LINK_PRESETS"] = "1"
        if resetStorage {
            app.launchEnvironment["ROCKEROOM_RESET_STORAGE"] = "1"
        }
        if let nowUnix {
            app.launchEnvironment["ROCKEROOM_NOW_UNIX"] = String(nowUnix)
        }
        if demoTunnelFailure {
            app.launchEnvironment["ROCKEROOM_DEMO_TUNNEL_FAILURE"] = "1"
        }
        if let demoSubscriptionPayloadB64 {
            app.launchEnvironment["ROCKEROOM_DEMO_SUBSCRIPTION_PAYLOAD_B64"] = demoSubscriptionPayloadB64
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
