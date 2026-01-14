import XCTest

final class OOMCPUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Menu bar app launch test
        // The app is a menu bar app (LSUIElement = YES), so we just verify launch
    }
}
