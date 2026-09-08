import Foundation

// The day boundary every "of the day" feature shares: the Ayah, Hadith, Dua, Word, Name and
// Reminder of the Day all turn over together. In Al-Islam the boundary is that day's Fajr from its
// own prayer calculation; this app ships no prayer calculation, so the boundary is local midnight
// (see the `Settings` extension below, which keeps the same entry points).
//
// Compiled into every target: the widget extension applies the same rule to the Fajr table the
// app writes into the shared snapshot, so the two never disagree about which day it is.
enum DailyRollover {
    /// The calendar day `date` belongs to once the boundary is applied: the start of its own day,
    /// or of the day before when `date` falls earlier than that day's Fajr.
    static func anchoredDay(for date: Date, fajr: Date?, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        if let fajr, date < fajr, let previous = calendar.date(byAdding: .day, value: -1, to: start) {
            return previous
        }
        return start
    }

    /// Whole days from the epoch to the (anchored) day, in the local calendar.
    static func index(ofDay day: Date, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0), to: day).day ?? 0
    }

    /// The rule applied with a table of Fajr times keyed by calendar day ("yyyy-MM-dd"), which is
    /// what the widget extension has instead of the prayer calculation.
    static func dayIndex(for date: Date, fajrByDay: [String: TimeInterval]?, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: date)
        let fajr = fajrByDay?[Settings.dayKey(start)].map { Date(timeIntervalSince1970: $0) }
        return index(ofDay: anchoredDay(for: date, fajr: fajr, calendar: calendar), calendar: calendar)
    }

    /// The next moment the day turns over after `date`, from the same table.
    static func nextRollover(after date: Date, fajrByDay: [String: TimeInterval]?, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: date)
        let todayFajr = fajrByDay?[Settings.dayKey(start)].map { Date(timeIntervalSince1970: $0) }
        if let todayFajr, date < todayFajr { return todayFajr }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start) ?? date.addingTimeInterval(86_400)
        let tomorrowFajr = fajrByDay?[Settings.dayKey(tomorrow)].map { Date(timeIntervalSince1970: $0) }
        return tomorrowFajr ?? tomorrow
    }
}

extension Settings {
    /// This app ships no prayer calculation, so there is no Fajr to anchor the day to: the daily
    /// boundary is always local midnight. Kept as the same entry point the shared code calls, so
    /// `DailyRollover` and its callers read identically across the three apps.
    func dailyFajr(for date: Date = Date()) -> Date? { nil }

    /// The day `date` belongs to under the daily boundary (start of that day).
    func dailyAnchor(for date: Date = Date()) -> Date {
        DailyRollover.anchoredDay(for: date, fajr: dailyFajr(for: date))
    }

    /// The daily features' day counter: every "of the day" pick is `corpus[dailyDayIndex % count]`.
    func dailyDayIndex(for date: Date = Date()) -> Int {
        DailyRollover.index(ofDay: dailyAnchor(for: date))
    }

    /// "yyyy-MM-dd" of the day `date` belongs to under the daily boundary.
    func dailyDayKey(for date: Date = Date()) -> String {
        Self.dayKey(dailyAnchor(for: date))
    }

    /// When the daily features next turn over: the next local midnight.
    func nextDailyRollover(after date: Date = Date()) -> Date {
        let anchor = dailyAnchor(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: anchor) ?? date.addingTimeInterval(86_400)
    }

    /// The widget extension's Fajr table, empty here for the same reason `dailyFajr` is nil: with no
    /// prayer calculation the widgets fall back to midnight, exactly as the app does.
    func fajrTable(days: Int = 30) -> [String: TimeInterval] { [:] }

}
