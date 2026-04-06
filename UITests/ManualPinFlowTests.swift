import XCTest

final class ManualPinFlowTests: XCTestCase {
    @MainActor
    func testExpertConsoleIsReachableFromTabShell() {
        let app = configuredApp(storageSuite: "ui-console-reachability", resetStorage: true)
        app.launch()

        importAndBenchmark(in: app)

        app.tabBars.buttons["Expert Console"].tap()

        XCTAssertTrue(app.navigationBars["Expert Console"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["expertConsoleRouteContextSection"].waitForExistence(timeout: 5))
        XCTAssertTrue(expertConsoleHistoryIsVisible(in: app))
        XCTAssertTrue(scrollToElement(app.buttons["pinCandidateButton.stable-relay"], in: app))
    }

    @MainActor
    func testPinnedProviderPreventsAutoSwitch() {
        let app = configuredApp(storageSuite: "ui-manual-pin-flow", resetStorage: true)
        app.launch()

        importAndBenchmark(in: app)

        app.tabBars.buttons["Expert Console"].tap()
        XCTAssertTrue(scrollToElement(app.buttons["pinCandidateButton.stable-relay"], in: app))
        app.buttons["pinCandidateButton.stable-relay"].tap()

        XCTAssertTrue(app.otherElements["expertConsoleControlSection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["expertConsoleControlStateBadge"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["expertConsoleControlStateBadge"].label, "Manual")
        XCTAssertTrue(app.staticTexts["Pinned"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Home"].tap()

        XCTAssertTrue(app.staticTexts["Manual selection is active. Unpin it from Expert Console to return to automatic recommendation."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current setup: Stable Relay"].exists)

        app.buttons["benchmarkButton"].tap()

        XCTAssertTrue(app.staticTexts["Manual selection is active. Unpin it from Expert Console to return to automatic recommendation."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Current setup: Stable Relay"].exists)
    }

    @MainActor
    func testUnpinResumesPolicyControlledRecommendation() {
        let app = configuredApp(storageSuite: "ui-manual-unpin-flow", resetStorage: true)
        app.launch()

        importAndBenchmark(in: app)

        app.tabBars.buttons["Expert Console"].tap()
        XCTAssertTrue(scrollToElement(app.buttons["pinCandidateButton.stable-relay"], in: app))
        app.buttons["pinCandidateButton.stable-relay"].tap()
        XCTAssertTrue(app.buttons["unpinCandidateButton.stable-relay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["expertConsoleControlStateBadge"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["expertConsoleControlStateBadge"].label, "Manual")
        app.buttons["unpinCandidateButton.stable-relay"].tap()

        app.tabBars.buttons["Home"].tap()

        XCTAssertFalse(app.staticTexts["Manual selection is active. Unpin it from Expert Console to return to automatic recommendation."].exists)
        XCTAssertTrue(app.staticTexts["Current setup: Fast Relay"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended setup"].exists)
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
    private func importAndBenchmark(in app: XCUIApplication) {
        app.buttons["useValidDemoLinkButton"].tap()
        app.buttons["importSubscriptionButton"].tap()
        app.buttons["benchmarkButton"].tap()

        XCTAssertTrue(app.staticTexts["Recommended setup"].waitForExistence(timeout: 5))
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

    @MainActor
    private func expertConsoleHistoryIsVisible(in app: XCUIApplication) -> Bool {
        scrollToElement(app.otherElements["routeHistoryRow.openai"], in: app)
            || scrollToElement(app.staticTexts["routeHistoryEmptyState"], in: app)
    }
}
