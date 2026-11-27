import Foundation

/// The three Read later presets from the spec.
public enum ReminderPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case tonight, tomorrow, weekend

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        case .weekend: return "Weekend"
        }
    }

    /// Tonight 9:00 PM, Tomorrow 8:00 AM, Weekend = the next Saturday 10:00 AM.
    public func date(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        switch self {
        case .tonight:
            let today9 = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now)!
            return today9 > now ? today9 : calendar.date(byAdding: .day, value: 1, to: today9)!
        case .tomorrow:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!
        case .weekend:
            return calendar.nextDate(after: now, matching: DateComponents(hour: 10, minute: 0, second: 0, weekday: 7),
                                     matchingPolicy: .nextTime)!
        }
    }

    /// The preset whose date (from `now`) is the same minute as `date`, if any.
    public static func matching(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> ReminderPreset? {
        guard let date else { return nil }
        return allCases.first { abs($0.date(from: now, calendar: calendar).timeIntervalSince(date)) < 60 }
    }
}

/// Human wording for dates in the UI.
public enum DateText {
    /// Card date line: "Today", "Yesterday", or a short numeric date such as 11/24/2026.
    public static func dateLine(for date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: y) { return "Yesterday" }
        return numeric(date, calendar: calendar, locale: locale)
    }

    public static func numeric(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = locale
        f.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMddyyyy", options: 0, locale: locale) ?? "MM/dd/yyyy"
        return f.string(from: date)
    }

    /// "Saved today", "Saved yesterday", "Saved on 11/24/2026".
    public static func saved(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let line = dateLine(for: date, now: now, calendar: calendar, locale: locale)
        switch line {
        case "Today", "Yesterday": return "Saved " + line.lowercased()
        default: return "Saved on " + line
        }
    }

    /// Reminder wording: "Tonight, 9:00 PM", "Tomorrow, 8:00 AM", "Saturday, 10:00 AM", else a date.
    public static func reminder(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = DateFormatter()
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        time.locale = locale
        time.dateStyle = .none
        time.timeStyle = .short
        let t = time.string(from: date)
        let startNow = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startNow, to: startDate).day ?? 0
        let hour = calendar.component(.hour, from: date)
        switch days {
        case 0: return (hour >= 17 ? "Tonight, " : "Today, ") + t
        case 1: return "Tomorrow, " + t
        case 2...6:
            let wd = DateFormatter()
            wd.calendar = calendar
            wd.timeZone = calendar.timeZone
            wd.locale = locale
            wd.dateFormat = "EEEE"
            return wd.string(from: date) + ", " + t
        default:
            return numeric(date, calendar: calendar, locale: locale) + ", " + t
        }
    }
}
