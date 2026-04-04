import XCTest

final class FirstRunOptimizeFlowTests: XCTestCase {
    @MainActor
    func testFirstRunLaunchesToAutoModeShell() {
        let app = configuredApp(storageSuite: "ui-first-run-shell", resetStorage: true)
        app.launch()

        XCTAssertTrue(app.staticTexts["Auto Mode"].exists)
        XCTAssertTrue(app.buttons["importClashSubscriptionButton"].exists)
        XCTAssertTrue(app.buttons["optimizeButton"].exists)
    }

    @MainActor
    func testClashSubscriptionImportOptimizeAndRestoreFlow() {
        let suite = "ui-first-run-optimize-restore"
        let app = configuredApp(storageSuite: suite, resetStorage: true)
        app.launch()

        app.buttons["importClashSubscriptionButton"].tap()
        XCTAssertTrue(app.buttons["useValidDemoLinkButton"].waitForExistence(timeout: 2))
        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        app.buttons["optimizeButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Tunnel: running"].exists)
        app.buttons["openMarketplaceButton"].tap()
        XCTAssertTrue(app.navigationBars["Marketplace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["marketplaceSummaryText"].waitForExistence(timeout: 5))

        app.terminate()

        let relaunched = configuredApp(storageSuite: suite, resetStorage: false)
        relaunched.launch()

        XCTAssertTrue(relaunched.staticTexts["Tunnel: running"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            relaunched.staticTexts["Recommended setup"].exists ||
            relaunched.staticTexts["Best current setup"].exists
        )
        XCTAssertTrue(
            relaunched.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Current setup:")).firstMatch.waitForExistence(timeout: 5)
        )
        relaunched.buttons["openMarketplaceButton"].tap()
        XCTAssertTrue(relaunched.navigationBars["Marketplace"].waitForExistence(timeout: 5))
        XCTAssertTrue(relaunched.staticTexts["marketplaceSummaryText"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testInvalidSubscriptionCanRecoverWithoutLosingFlow() {
        let app = configuredApp(storageSuite: "ui-first-run-recovery", resetStorage: true)
        app.launch()

        app.buttons["importClashSubscriptionButton"].tap()
        XCTAssertTrue(app.buttons["useInvalidDemoLinkButton"].waitForExistence(timeout: 2))
        app.buttons["useInvalidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()

        let errorMessage = app.staticTexts["Could not load the Clash subscription link."]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 5))

        app.buttons["importClashSubscriptionButton"].tap()
        XCTAssertTrue(app.buttons["useValidDemoLinkButton"].waitForExistence(timeout: 2))
        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()
        app.buttons["optimizeButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMarketplaceEmptyStateIsReachableBeforeOptimize() {
        let app = configuredApp(storageSuite: "ui-marketplace-empty-state", resetStorage: true)
        app.launch()

        app.buttons["openMarketplaceButton"].tap()

        XCTAssertTrue(app.navigationBars["Marketplace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["marketplaceEmptyState"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func configuredApp(storageSuite: String, resetStorage: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ROCKEROOM_STORAGE_SUITE"] = storageSuite
        app.launchEnvironment["ROCKEROOM_USE_DEMO_FETCHER"] = "1"
        app.launchEnvironment["ROCKEROOM_USE_DEMO_TUNNEL"] = "1"
        app.launchEnvironment["ROCKEROOM_SHOW_TEST_LINK_PRESETS"] = "1"
        if resetStorage {
            app.launchEnvironment["ROCKEROOM_RESET_STORAGE"] = "1"
        }
        return app
    }
}
