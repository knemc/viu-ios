import XCTest

final class VIUUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor
    func testAccountControlsAndNavigation() {
        let app = XCUIApplication()
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 15))
        for title in ["Home", "Movies", "TV", "Live", "Account"] {
            XCTAssertTrue(tabs.buttons[title].exists, "Missing tab: \(title)")
        }
        tabs.buttons["Account"].tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Account settings"].exists)
        XCTAssertTrue(app.buttons["Clear local playback progress"].exists)
        capture(app, "Account portrait")
        app.buttons["Clear local playback progress"].tap()
        XCTAssertTrue(app.buttons["Clear progress"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        capture(app, "Account landscape")
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testLargeTextAccountLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let account = app.tabBars.buttons["Account"]
        XCTAssertTrue(account.waitForExistence(timeout: 15))
        account.tap()
        XCTAssertTrue(app.navigationBars["Account"].waitForExistence(timeout: 5))
        capture(app, "Account large text")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
