import XCTest

final class PullToRefreshTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
    }

    func testTheSiteRefreshesOnALongPull() {
        check(serving: "site")
    }

    private func check(serving page: String) {
        _ = server("__mode/\(page)")
        app.launchArguments += ["-signed_in", "YES", "-AppleLanguages", "(en)"]
        app.launch()
        let view = app.windows.firstMatch
        sleep(20)
        keep("\(page) opened")
        let before = server("__loads")

        pull(view, from: 0.3, to: 0.38)
        sleep(3)
        let afterShort = server("__loads")
        pull(view, from: 0.3, to: 0.85)
        keep("\(page) released")
        sleep(5)
        let afterLong = server("__loads")
        keep("\(page) after")
        print("pull result \(page): loads before \(before), after a short pull \(afterShort), after a long pull \(afterLong)")
        XCTAssertEqual(afterShort, before, "a short pull refreshed the \(page) page")
        XCTAssertGreaterThan(afterLong, afterShort, "a long pull did not refresh the \(page) page")
    }

    private func server(_ path: String) -> Int {
        let done = expectation(description: path)
        var answer = ""
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:3000/\(path)")!) { data, _, _ in
            answer = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 30)
        return Int(answer) ?? -1
    }

    private func pull(_ view: XCUIElement, from start: CGFloat, to end: CGFloat) {
        let from = view.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
        let to = view.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.4)
    }

    private func keep(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
