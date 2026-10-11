import Foundation

/// Fixed date and time rules applied in code, never left to the model (RISKS C3).
public enum TimeRules {
    /// Friday's day starts at 04:00: at 1 a.m. it is still "yesterday" for the Today screen,
    /// rollover and focus.
    public static func today(now: Date, in timeZone: TimeZone) -> Day {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: now)
        let day = Day(now, in: timeZone)
        return hour < 4 ? day.adding(days: -1) : day
    }

    /// Between 00:00 and 04:00, "tomorrow" means the coming day, which is already today's date.
    public static func fixTomorrow(_ date: Day, said: String, now: Date, in timeZone: TimeZone) -> Day {
        let calendarToday = Day(now, in: timeZone)
        guard calendarToday != today(now: now, in: timeZone),
              date == calendarToday.adding(days: 1),
              Rx.contains(said, Rx.wordStart + "tomorrow" + Rx.wordEnd)
        else { return date }
        return calendarToday
    }

    private static let meridiem = Rx.wordStart
        + "(?:am|pm|a\\.m\\.?|p\\.m\\.?|morning|evening|night|tonight|afternoon|noon|midnight)" + Rx.wordEnd

    /// Bare hours ("at 5") mean 1–7 → PM and 8–11 → AM. Only applies when the user said no
    /// am/pm-type word and didn't say the hour in 24-hour form.
    public static func fixBareHour(_ time: TimeOfDay, said: String) -> TimeOfDay {
        if Rx.contains(said, meridiem) { return time }
        if (1...7).contains(time.hour) {
            return TimeOfDay(hour: time.hour + 12, minute: time.minute)!
        }
        if (20...23).contains(time.hour), !Rx.contains(said, Rx.wordStart + "\(time.hour)" + Rx.wordEnd) {
            return TimeOfDay(hour: time.hour - 12, minute: time.minute)!
        }
        return time
    }
}
