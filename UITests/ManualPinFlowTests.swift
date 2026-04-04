import XCTest

final class ManualPinFlowTests: XCTestCase {
    @MainActor
    func testExpertConsoleIsReachableFromAutoMode() {
        let app = configuredApp(storageSuite: "ui-console-reachability", resetStorage: true)
        app.launch()

        importAndOptimize(in: app)

        app.buttons["openExpertConsoleButton"].tap()

        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2. Stable Relay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Pin Stable Relay"].exists)
    }

    @MainActor
    func testPinnedProviderPreventsAutoSwitch() {
        let app = configuredApp(storageSuite: "ui-manual-pin-flow", resetStorage: true)
        app.launch()

        importAndOptimize(in: app)

        app.buttons["openExpertConsoleButton"].tap()
        XCTAssertTrue(app.buttons["Pin Stable Relay"].waitForExistence(timeout: 5))
        app.buttons["Pin Stable Relay"].tap()

        XCTAssertTrue(app.staticTexts["Pinned"].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["Pinned provider active. Auto-switch is disabled."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current setup: Stable Relay"].exists)

        app.buttons["optimizeButton"].tap()

        XCTAssertTrue(app.staticTexts["Pinned provider active. Auto-switch is disabled."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current setup: Stable Relay"].exists)
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

    @MainActor
    private func importAndOptimize(in app: XCUIApplication) {
        app.buttons["importClashSubscriptionButton"].tap()
        XCTAssertTrue(app.buttons["useValidDemoLinkButton"].waitForExistence(timeout: 2))
        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()
        app.buttons["optimizeButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
    }
}
