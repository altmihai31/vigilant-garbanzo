import XCTest
import UIKit

/// Drives the app with the mockup's sample data and saves a screenshot of every screen.
/// Screenshots go to $SCREENSHOT_DIR (CI passes TEST_RUNNER_SCREENSHOT_DIR) and into the test results.
final class StashUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-StashDemo", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func tap(_ id: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        let e = el(id)
        XCTAssertTrue(e.waitForExistence(timeout: timeout), "Missing \(id)", file: file, line: line)
        e.tap()
    }

    private func waitGone(_ e: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let exp = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: e)
        return XCTWaiter().wait(for: [exp], timeout: timeout) == .completed
    }

    /// The Simulator shows a one-time "slide to type" sheet the first time the keyboard opens.
    private func dismissKeyboardTip() {
        let cont = app.buttons["Continue"]
        if cont.waitForExistence(timeout: 1.5) { cont.tap() }
    }

    private func menuItem(_ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func snap(_ name: String) {
        Thread.sleep(forTimeInterval: 0.9)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: url)
        }
    }

    func testTourOfScreens() {
        app.launch()
        XCTAssertTrue(el("card-Top Hotels on the Amalfi Coast").waitForExistence(timeout: 15))
        XCTAssertTrue(el("filterButton").label.contains("4 unread"), el("filterButton").label)
        snap("01-home")

        // Filter menu and a collection.
        tap("filterButton")
        let places = menuItem("Places")
        XCTAssertTrue(places.waitForExistence(timeout: 5))
        snap("02-filter-menu")
        places.tap()
        XCTAssertTrue(el("collectionTitle").waitForExistence(timeout: 5))
        XCTAssertEqual(el("collectionTitle").label, "Places")
        XCTAssertTrue(el("card-Best Sushi Spots in Tokyo for First-Time Visitors").exists)
        XCTAssertTrue(waitGone(el("card-Sony WH-1000XM6 Review")))
        snap("03-places")
        tap("showAll")

        // Detail with map, then the offline reader.
        tap("card-Top Hotels on the Amalfi Coast")
        XCTAssertTrue(el("detailTitle").waitForExistence(timeout: 5))
        snap("04-detail")
        el("detailView").swipeUp()
        XCTAssertTrue(el("openInMaps").waitForExistence(timeout: 5))
        snap("05-detail-location")
        el("detailView").swipeDown()
        el("detailView").swipeDown()
        tap("readOffline")
        XCTAssertTrue(el("readerView").waitForExistence(timeout: 5))
        snap("06-reader")
        tap("textSize")
        tap("closeReader")
        tap("backButton")
        // Reading it marked it read.
        XCTAssertTrue(el("filterButton").waitForExistence(timeout: 5))
        XCTAssertTrue(el("filterButton").label.contains("3 unread"), el("filterButton").label)

        // Search reaches the saved article text.
        tap("searchButton")
        let field = el("searchField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        dismissKeyboardTip()
        field.typeText("omakase")
        XCTAssertTrue(el("card-Best Sushi Spots in Tokyo for First-Time Visitors").waitForExistence(timeout: 5))
        XCTAssertTrue(waitGone(el("card-Top Hotels on the Amalfi Coast")))
        snap("07-search")
        tap("closeSearch")

        // Add a link: preview with summary and collection, then save.
        tap("addButton")
        let url = el("urlField")
        XCTAssertTrue(url.waitForExistence(timeout: 5))
        snap("08-add-link-empty")
        // The Paste button next to the field fills in a copied link.
        UIPasteboard.general.string = "https://monocle.com/travel/lisbon-city-guide"
        tap("pasteButton")
        // iOS may ask once whether Stash can paste from another app.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for allow in [app.buttons["Allow Paste"], springboard.buttons["Allow Paste"]] where allow.waitForExistence(timeout: 2) {
            allow.tap()
            break
        }
        XCTAssertTrue(el("linkPreview").waitForExistence(timeout: 10))
        snap("09-add-link-preview")
        tap("saveButton")
        let lisbon = el("card-Lisbon City Guide: Where to Stay, Eat and Shop")
        XCTAssertTrue(lisbon.waitForExistence(timeout: 8))
        snap("10-home-after-save")
        lisbon.tap()
        XCTAssertTrue(el("detailSummary").waitForExistence(timeout: 5))
        XCTAssertTrue(el("openInMaps").waitForExistence(timeout: 5) || el("placeMap").exists)
        snap("11-saved-link-detail")
        tap("backButton")

        // A note with a checklist.
        tap("addButton")
        tap("segment-Note")
        tap("noteTitleField")
        app.typeText("Weekend groceries")
        tap("addChecklistItem")
        app.typeText("Tomatoes")
        tap("addChecklistItem")
        app.typeText("Pecorino")
        snap("12-new-note")
        tap("saveButton")
        tap("card-Weekend groceries")
        XCTAssertTrue(el("detailTitle").waitForExistence(timeout: 5))
        tap("check-Tomatoes")
        XCTAssertEqual(el("check-Tomatoes").value as? String, "done")
        snap("13-note-detail")
        tap("backButton")

    }

    func testReadLater() {
        app.launch()
        tap("card-Sony WH-1000XM6 Review", timeout: 15)
        XCTAssertTrue(el("readLaterStatus").waitForExistence(timeout: 5))
        el("detailView").swipeUp()
        tap("remind-Tomorrow")
        XCTAssertTrue(el("readLaterStatus").label.hasPrefix("Reminder: Tomorrow"), el("readLaterStatus").label)
        snap("15-reminder-set")
        tap("markRead")
        XCTAssertEqual(el("readLaterStatus").label, "You read this")
        // Swipe in from the left edge to go back.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        XCTAssertTrue(waitGone(el("detailView")), "Edge swipe did not go back")
        XCTAssertTrue(el("filterButton").label.contains("3 unread"), el("filterButton").label)

        tap("filterButton")
        let later = menuItem("Read later")
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        XCTAssertEqual(el("collectionTitle").label, "Read later")
        XCTAssertTrue(waitGone(el("card-Sony WH-1000XM6 Review")))
        snap("16-read-later")
    }
}
