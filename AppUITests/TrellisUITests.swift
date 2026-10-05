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
    func testDarkAndAccessibleTextScreens() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--dark"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15)); capture("08-dark-home")
        app.terminate(); app.launchArguments = ["--demo", "--large-text"]; app.launch()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 15)); capture("09-accessibility-home")
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
