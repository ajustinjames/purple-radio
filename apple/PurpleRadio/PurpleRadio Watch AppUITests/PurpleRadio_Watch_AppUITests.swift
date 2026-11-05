import XCTest

/// Launch smoke test. These run on the watch simulator and take a few minutes, so CI
/// runs only the unit tests; run the full scheme locally before merging app changes.
final class PurpleRadio_Watch_AppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// A fresh launch has no stored credentials, so `RootView` shows sign-in.
    @MainActor
    func testLaunchShowsSignIn() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Purple Radio"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["No live channels"].exists)
    }
}
