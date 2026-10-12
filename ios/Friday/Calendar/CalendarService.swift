import EventKit
import FridayCore
import Observation
import UIKit

/// The iPhone Calendar (EventKit): reads every calendar so Friday knows your schedule, adds new
/// events to a "Friday" calendar, and moves or cancels events when you ask. Every change can be undone.
@MainActor
@Observable
final class CalendarService {
    static let shared = CalendarService()

    /// Events from today through the next 14 days, earliest first.
    private(set) var events: [EKEvent] = []
    private(set) var authorized = CalendarService.hasAccess
    private let store = EKEventStore()

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }
    static var denied: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .denied || status == .restricted
    }

    private init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { CalendarService.shared.reload() }
        }
        reload()
    }

    /// Asks once; afterwards returns the saved answer straight away.
    func requestAccess() async -> Bool {
        if CalendarService.hasAccess {
            authorized = true
            return true
        }
        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, _ in continuation.resume(returning: granted) }
        }
        authorized = granted
        reload()
        return granted
    }

    func reload() {
        guard CalendarService.hasAccess else {
            events = []
            return
        }
        let start = Calendar.current.startOfDay(for: .now)
        guard let end = Calendar.current.date(byAdding: .day, value: 15, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    /// Today's events (Friday's day runs 04:00 to 04:00).
    func today() -> [EKEvent] {
        let day = TimeRules.today(now: .now, in: .current)
        return events.filter { TimeRules.today(now: $0.startDate, in: .current) == day }
    }

    /// The EVENTS list for the decision engine, with short ids ("e1"…) and the events they stand for.
    func forPrompt() -> (events: [CalendarEvent], byID: [String: EKEvent]) {
        var list: [CalendarEvent] = []
        var byID: [String: EKEvent] = [:]
        for (i, event) in events.prefix(40).enumerated() {
            let id = "e\(i + 1)"
            byID[id] = event
            list.append(CalendarEvent(
                id: id, title: event.title ?? "Event", date: Day(event.startDate, in: .current),
                time: event.isAllDay ? nil : CalendarService.time(event.startDate),
                end: event.isAllDay ? nil : CalendarService.time(event.endDate),
                calendar: event.calendar?.title ?? ""))
        }
        return (list, byID)
    }

    // MARK: Changes

    /// How to put a change back.
    enum Undo {
        case remove(String)
        case restore(title: String, start: Date, end: Date, calendarID: String, notes: String?)
        case moveBack(String, start: Date, end: Date)
    }

    struct Failed: Error {}

    func add(title: String, start: Date, minutes: Int?) throws -> Undo {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(Double(minutes ?? 30) * 60)
        event.calendar = fridayCalendar()
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
        try store.save(event, span: .thisEvent, commit: true)
        guard let id = event.eventIdentifier else { throw Failed() }
        reload()
        return .remove(id)
    }

    func move(_ event: EKEvent, to start: Date) throws -> Undo {
        let undo = Undo.moveBack(event.eventIdentifier ?? "", start: event.startDate, end: event.endDate)
        let length = event.endDate.timeIntervalSince(event.startDate)
        event.startDate = start
        event.endDate = start.addingTimeInterval(length)
        try store.save(event, span: .thisEvent, commit: true)
        reload()
        return undo
    }

    func cancel(_ event: EKEvent) throws -> Undo {
        let undo = Undo.restore(title: event.title ?? "Event", start: event.startDate, end: event.endDate,
                                calendarID: event.calendar?.calendarIdentifier ?? "", notes: event.notes)
        try store.remove(event, span: .thisEvent, commit: true)
        reload()
        return undo
    }

    func undo(_ steps: [Undo]) {
        for step in steps.reversed() {
            switch step {
            case .remove(let id):
                if let event = store.event(withIdentifier: id) { try? store.remove(event, span: .thisEvent, commit: true) }
            case let .restore(title, start, end, calendarID, notes):
                let event = EKEvent(eventStore: store)
                event.title = title
                event.startDate = start
                event.endDate = end
                event.notes = notes
                event.calendar = store.calendar(withIdentifier: calendarID) ?? fridayCalendar()
                try? store.save(event, span: .thisEvent, commit: true)
            case let .moveBack(id, start, end):
                if let event = store.event(withIdentifier: id) {
                    event.startDate = start
                    event.endDate = end
                    try? store.save(event, span: .thisEvent, commit: true)
                }
            }
        }
        reload()
    }

    /// The "Friday" calendar, made once next to the default calendar.
    private func fridayCalendar() -> EKCalendar? {
        if let existing = store.calendars(for: .event).first(where: { $0.title == "Friday" && $0.allowsContentModifications }) {
            return existing
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = "Friday"
        calendar.cgColor = UIColor.black.cgColor
        calendar.source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local || $0.sourceType == .calDAV }
        if (try? store.saveCalendar(calendar, commit: true)) != nil { return calendar }
        return store.defaultCalendarForNewEvents
    }

    static func time(_ date: Date) -> TimeOfDay? {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    static func date(_ day: Day, _ time: TimeOfDay) -> Date? {
        Calendar.current.date(from: DateComponents(year: day.year, month: day.month, day: day.day,
                                                   hour: time.hour, minute: time.minute))
    }
}
