import XCTest

final class PullToRefreshTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments += ["-signed_in", "YES", "-AppleLanguages", "(en)"]
        app.launch()
    }

    func testPullingTheScreenDownRefreshesIt() {
        let page = app.webViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 60), "the first screen never showed a web view")
        sleep(4)
        keep("opened")

        pull(page, from: 0.3, to: 0.85)
        keep("released")
        let console = app.otherElements["pull-console"]
        XCTAssertTrue(console.exists, "the pull console is not in the window")
        print("pull console after a long pull: \(String(describing: console.value))")
        XCTAssertEqual(console.value as? String, "SYNC", "a long pull did not start a refresh")
    }

    func testAShortPullLetsGoWithoutRefreshing() {
        let page = app.webViews.firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 60))
        sleep(4)

        pull(page, from: 0.3, to: 0.38)
        let console = app.otherElements["pull-console"]
        print("pull console after a short pull: \(String(describing: console.value))")
        XCTAssertNotEqual(console.value as? String, "SYNC", "a short pull refreshed")
    }

    private func pull(_ page: XCUIElement, from start: CGFloat, to end: CGFloat) {
        let from = page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
        let to = page.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.4)
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
