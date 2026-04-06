import XCTest

final class LiveE2EWorkflowTests: XCTestCase {
    @MainActor
    func testDebugOverlayRemainsVisibleWhenOpenedAndLeftIdle() throws {
        let app = configuredManualDebugApp(storageSuite: "ui-debug-overlay-open-idle", resetStorage: true)

        app.launch()

        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()

        XCTAssertTrue(app.buttons["Import demo subscription"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.textFields["debugLiveImportLinkField"].exists)

        sleep(2)

        XCTAssertTrue(app.textFields["debugLiveImportLinkField"].exists)
        XCTAssertTrue(app.buttons["Import demo subscription"].exists)
    }

    @MainActor
    func testDebugOverlayRemainsVisibleWhileEditingLiveURL() throws {
        let app = configuredManualDebugApp(storageSuite: "ui-debug-overlay-edit-live-url", resetStorage: true)

        app.launch()

        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()

        let field = app.textFields["debugLiveImportLinkField"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        field.typeText("https://provider.example.com/subscription")

        XCTAssertTrue(app.textFields["debugLiveImportLinkField"].exists)
        XCTAssertTrue(app.buttons["debugImportTypedURLButton"].exists)
    }

    @MainActor
    func testDebugOverlayDeterministicImportLandsOnNormalHomeFlow() throws {
        let app = configuredManualDebugApp(storageSuite: "ui-debug-overlay-demo-import", resetStorage: true)

        app.launch()

        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()
        XCTAssertTrue(app.buttons["Import demo subscription"].waitForExistence(timeout: 8))
        app.buttons["Import demo subscription"].tap()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["benchmarkButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertFalse(app.staticTexts["Ranked candidates"].exists)
    }

    @MainActor
    func testDebugOverlayDeterministicImportRunsBenchmarkAndOpensExpertConsole() throws {
        let app = configuredManualDebugApp(storageSuite: "ui-debug-overlay-demo-benchmark", resetStorage: true)

        app.launch()

        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()
        XCTAssertTrue(app.buttons["Import demo subscription"].waitForExistence(timeout: 8))
        app.buttons["Import demo subscription"].tap()

        let benchmarkButton = app.buttons["benchmarkButton"]
        XCTAssertTrue(benchmarkButton.waitForExistence(timeout: 8))
        benchmarkButton.tap()

        XCTAssertTrue(app.staticTexts["Measured recommendation"].waitForExistence(timeout: 8))

        app.tabBars.buttons["Expert Console"].tap()
        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertConsoleRouteContextSection"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertConsoleControlSection"].exists)
        XCTAssertTrue(expertConsoleHistoryIsVisible(in: app))
        XCTAssertTrue(app.staticTexts["Ranked candidates"].exists)
    }

    @MainActor
    func testDebugOverlayResetReturnsImportedSessionToSetupScreen() throws {
        let app = configuredManualDebugApp(storageSuite: "ui-debug-overlay-reset", resetStorage: true)

        app.launch()

        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()
        XCTAssertTrue(app.buttons["Import demo subscription"].waitForExistence(timeout: 8))
        app.buttons["Import demo subscription"].tap()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["debugOverlayButton"].waitForExistence(timeout: 8))
        app.buttons["debugOverlayButton"].tap()
        XCTAssertTrue(app.buttons["Reset app"].waitForExistence(timeout: 8))
        app.buttons["Reset app"].tap()

        XCTAssertTrue(app.staticTexts["setupScreenHeader"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["importSubscriptionButton"].waitForExistence(timeout: 8))
    }

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
        XCTAssertTrue(app.otherElements["expertConsoleRouteContextSection"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.otherElements["expertConsoleControlSection"].exists)
        XCTAssertTrue(expertConsoleHistoryIsVisible(in: app))
        XCTAssertTrue(app.otherElements["routeHistoryRow.openai"].exists)
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
            scenario: "expert-console",
            resetStorage: true,
            nowUnix: 100,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        firstPass.launch()

        assertBenchmarkedConsoleState(in: firstPass)
        firstPass.terminate()

        let staleHint = configuredApp(
            storageSuite: suite,
            scenario: "stale-hint",
            resetStorage: false,
            nowUnix: 2_000,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        staleHint.launch()

        XCTAssertTrue(
            staleHint.staticTexts["Refresh available. Run Benchmark again to update stale evidence."].waitForExistence(timeout: 8)
        )
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
        XCTAssertFalse(refreshed.staticTexts["Refresh available. Run Benchmark again to update stale evidence."].exists)
    }

    // MARK: - Destination-Aware Routing Scenario Contract Tests

    @MainActor
    func testScenarioDrivenAutoModeApplyRestoresRecommendedHomeState() throws {
        let importSuite = "ui-live-e2e-auto-mode-apply-import"
        let importApp = configuredApp(
            storageSuite: importSuite,
            scenario: "expert-console",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        importApp.launch()
        assertBenchmarkedConsoleState(in: importApp, timeout: 12)
        importApp.terminate()

        let routingApp = configuredApp(
            storageSuite: importSuite,
            scenario: "auto-mode-apply",
            resetStorage: false,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        routingApp.launch()

        XCTAssertTrue(routingApp.staticTexts["recommendationCard"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            routingApp.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Measured")).firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            routingApp.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
        XCTAssertFalse(routingApp.staticTexts["refreshHintText"].exists)
        XCTAssertFalse(
            routingApp.staticTexts["Manual selection is active. Unpin it from Expert Console to return to automatic recommendation."].exists
        )
    }

    @MainActor
    func testScenarioDrivenManualModeAdvisoryOpensExpertConsole() throws {
        let importSuite = "ui-live-e2e-manual-mode-advisory-import"
        let importApp = configuredApp(
            storageSuite: importSuite,
            scenario: "expert-console",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        importApp.launch()
        assertBenchmarkedConsoleState(in: importApp, timeout: 12)
        importApp.terminate()

        let routingApp = configuredApp(
            storageSuite: importSuite,
            scenario: "manual-mode-advisory",
            resetStorage: false,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        routingApp.launch()

        XCTAssertTrue(routingApp.staticTexts["Expert Console"].waitForExistence(timeout: 12))
        XCTAssertTrue(routingApp.otherElements["expertConsoleRouteContextSection"].waitForExistence(timeout: 8))
        XCTAssertTrue(routingApp.otherElements["expertConsoleControlSection"].exists)
        XCTAssertTrue(expertConsoleHistoryIsVisible(in: routingApp))
        XCTAssertTrue(
            routingApp.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Pin ")).firstMatch.waitForExistence(timeout: 8)
        )
    }

    @MainActor
    func testScenarioDrivenOverrideOrPinRestoresPinnedHomeState() throws {
        let app = configuredApp(
            storageSuite: "ui-live-e2e-override-or-pin",
            scenario: "override-or-pin",
            resetStorage: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        app.launch()

        XCTAssertTrue(app.buttons["benchmarkButton"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Best current setup"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["Pinned provider active. Manual selection stays in effect until you unpin it in Expert Console."]
                .waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 8)
        )
    }

    @MainActor
    func testScenarioDrivenStaleOrRefreshRestoresStaleHomeState() throws {
        let suite = "ui-live-e2e-stale-or-refresh"
        let seeded = configuredApp(
            storageSuite: suite,
            scenario: "expert-console",
            resetStorage: true,
            nowUnix: 100,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        seeded.launch()
        assertBenchmarkedConsoleState(in: seeded, timeout: 12)
        seeded.terminate()

        let routingApp = configuredApp(
            storageSuite: suite,
            scenario: "stale-or-refresh",
            resetStorage: false,
            nowUnix: 2_000,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        routingApp.launch()

        XCTAssertTrue(routingApp.buttons["benchmarkButton"].waitForExistence(timeout: 12))
        XCTAssertTrue(routingApp.staticTexts["Best current setup"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            routingApp.staticTexts["Refresh available. Run Benchmark again to update stale evidence."].waitForExistence(timeout: 8)
        )
    }

    @MainActor
    func testScenarioDrivenFailedReassignmentStopsOnRecoverableFailureState() throws {
        let app = configuredApp(
            storageSuite: "ui-live-e2e-failed-reassignment",
            scenario: "failed-reassignment",
            resetStorage: true,
            demoTunnelFailure: true,
            demoSubscriptionPayloadB64: try liveSubscriptionPayloadBase64()
        )
        app.launch()

        XCTAssertTrue(app.buttons["benchmarkButton"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Could not start the RockeRoom tunnel."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["benchmarkButton"].exists)
    }

    // MARK: - Helper

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

    @MainActor
    private func configuredManualDebugApp(storageSuite: String, resetStorage: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ROCKEROOM_STORAGE_SUITE"] = storageSuite
        app.launchEnvironment["ROCKEROOM_RESET_STORAGE"] = resetStorage ? "1" : "0"
        return app
    }

    @MainActor
    private func assertBenchmarkedConsoleState(in app: XCUIApplication, timeout: TimeInterval = 8) {
        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Ranked candidates"].waitForExistence(timeout: timeout))
    }

    @MainActor
    private func expertConsoleHistoryIsVisible(in app: XCUIApplication) -> Bool {
        scrollToElement(app.otherElements["routeHistoryRow.openai"], in: app)
            || scrollToElement(app.staticTexts["routeHistoryEmptyState"], in: app)
    }

    @discardableResult
    @MainActor
    private func scrollToElement(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }

        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) {
                return true
            }
        }

        return element.exists
    }

    private func liveSubscriptionPayloadBase64() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../Tests/Fixtures/live-vless-subscription.txt")
        let data = try Data(contentsOf: url)
        return data.base64EncodedString()
    }
}
