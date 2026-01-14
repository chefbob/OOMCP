import XCTest

final class OOMCPUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        // Menu bar apps don't have traditional windows
        // Just verify the app launched without crashing
        XCTAssertTrue(app.exists)
    }
}
