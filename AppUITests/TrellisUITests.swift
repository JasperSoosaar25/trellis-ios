import XCTest

@MainActor final class TrellisUITests: XCTestCase {
    func testMainScreens() throws {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15))
        capture("01-home")
        app.tabBars.buttons["Repositories"].tap()
        XCTAssertTrue(app.staticTexts["river-demo/garden-notes"].waitForExistence(timeout: 10))
        capture("02-repositories")
        app.staticTexts["river-demo/garden-notes"].tap()
        XCTAssertTrue(app.buttons["Actions"].waitForExistence(timeout: 10) || app.staticTexts["Actions"].exists)
        capture("03-repository")
        app.staticTexts["Actions"].tap()
        XCTAssertTrue(app.navigationBars["Actions"].waitForExistence(timeout: 10))
        let banner = app.staticTexts["statusBanner"]
        if banner.exists { XCTAssertGreaterThanOrEqual(app.navigationBars["Actions"].frame.minY, banner.frame.maxY - 1, "Status banner must not cover navigation controls") }
        capture("04-actions")
        app.tabBars.buttons["Inbox"].tap()
        XCTAssertTrue(app.navigationBars["Inbox"].waitForExistence(timeout: 10))
        capture("05-inbox")
        app.tabBars.buttons["Search"].tap()
        capture("06-search")
        app.tabBars.buttons["More"].tap()
        capture("07-more")
    }
    func testLoginHasRuntimeClientIDAndTokenEntry() {
        let app = XCUIApplication(); app.launchArguments = []; app.launch()
        XCTAssertTrue(app.secureTextFields["Personal access token"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["OAuth client ID"].exists)
        capture("00-login")
    }
    func testCommentDeletionRequiresConfirmation() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Repositories"].tap()
        let repository = app.staticTexts["river-demo/garden-notes"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10)); repository.tap()
        app.staticTexts["Issues"].tap()
        let issue = app.staticTexts["Improve accessibility in the file browser"]
        XCTAssertTrue(issue.waitForExistence(timeout: 10)); issue.tap()
        XCTAssertTrue(app.navigationBars["Issue #24"].waitForExistence(timeout: 10))
        capture("10-issue-markdown")
        let menu = app.buttons["Comment actions"].firstMatch
        for _ in 0..<5 { if menu.exists && menu.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(menu.exists); menu.tap()
        app.buttons["Delete comment"].tap()
        let confirmation = app.buttons["Delete your comment"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        capture("11-comment-confirmation")
        let cancel = app.buttons["Cancel"]
        if cancel.exists {
            cancel.tap()
        } else {
            // The system popover omits Cancel; tapping outside dismisses it.
            app.navigationBars["Issue #24"].coordinate(withNormalizedOffset: .init(dx: 0.5, dy: 0.5)).tap()
        }
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Thanks for checking. The next update improves readability."].waitForExistence(timeout: 5))
    }
    func testDarkAndAccessibleTextScreens() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--dark"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15)); capture("08-dark-home")
        app.terminate(); app.launchArguments = ["--demo", "--large-text"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15)); capture("09-accessibility-home")
    }
    private func capture(_ name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
