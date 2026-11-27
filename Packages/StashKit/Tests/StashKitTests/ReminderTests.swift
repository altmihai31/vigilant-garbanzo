import XCTest
@testable import StashKit

final class ReminderTests: XCTestCase {
    var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Bucharest")!
        c.firstWeekday = 2
        return c
    }()
    let us = Locale(identifier: "en_US")

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testPresets() {
        let fridayNoon = date(2026, 11, 27, 12)
        XCTAssertEqual(ReminderPreset.tonight.date(from: fridayNoon, calendar: cal), date(2026, 11, 27, 21))
        XCTAssertEqual(ReminderPreset.tomorrow.date(from: fridayNoon, calendar: cal), date(2026, 11, 28, 8))
        XCTAssertEqual(ReminderPreset.weekend.date(from: fridayNoon, calendar: cal), date(2026, 11, 28, 10))
        // After 9 PM "Tonight" moves to the next evening; Saturday afternoon "Weekend" means next Saturday.
        XCTAssertEqual(ReminderPreset.tonight.date(from: date(2026, 11, 27, 22), calendar: cal), date(2026, 11, 28, 21))
        XCTAssertEqual(ReminderPreset.weekend.date(from: date(2026, 11, 28, 11), calendar: cal), date(2026, 12, 5, 10))
        XCTAssertEqual(ReminderPreset.weekend.date(from: date(2026, 11, 28, 9), calendar: cal), date(2026, 11, 28, 10))
    }

    func testMatchingPreset() {
        let now = date(2026, 11, 27, 12)
        XCTAssertEqual(ReminderPreset.matching(date(2026, 11, 28, 8), now: now, calendar: cal), .tomorrow)
        XCTAssertNil(ReminderPreset.matching(date(2026, 11, 28, 9), now: now, calendar: cal))
        XCTAssertNil(ReminderPreset.matching(nil, now: now, calendar: cal))
    }

    func testDateLines() {
        let now = date(2026, 11, 27, 12)
        XCTAssertEqual(DateText.dateLine(for: date(2026, 11, 27, 1), now: now, calendar: cal, locale: us), "Today")
        XCTAssertEqual(DateText.dateLine(for: date(2026, 11, 26, 23), now: now, calendar: cal, locale: us), "Yesterday")
        XCTAssertEqual(DateText.dateLine(for: date(2026, 11, 24), now: now, calendar: cal, locale: us), "11/24/2026")
        XCTAssertEqual(DateText.saved(date(2026, 11, 24), now: now, calendar: cal, locale: us), "Saved on 11/24/2026")
        XCTAssertEqual(DateText.saved(date(2026, 11, 27, 9), now: now, calendar: cal, locale: us), "Saved today")
    }

    func testReminderWording() {
        let now = date(2026, 11, 27, 12)
        XCTAssertEqual(DateText.reminder(date(2026, 11, 27, 21), now: now, calendar: cal, locale: us), "Tonight, 9:00\u{202F}PM")
        XCTAssertEqual(DateText.reminder(date(2026, 11, 28, 8), now: now, calendar: cal, locale: us), "Tomorrow, 8:00\u{202F}AM")
        XCTAssertEqual(DateText.reminder(date(2026, 11, 30, 10), now: now, calendar: cal, locale: us), "Monday, 10:00\u{202F}AM")
    }
}
