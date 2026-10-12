import EventKit
import FridayCore
import Foundation

/// Talking on Home: Friday decides what you meant and does it — to-dos, iPhone Calendar
/// events, boxes. Anything it can't act on is kept as a box. One pill, one Undo for all of it.
@MainActor
enum Manager {
    static func handle(_ said: String) async {
        _ = await CalendarService.shared.requestAccess()
        let calendar = CalendarService.shared.forPrompt()
        let store = BoxStore.shared.store

        guard let actions = await Decider.shared.decide(said: said, store: store, events: calendar.events) else {
            // No AI answered (free limit used up or offline): keep the words, and say why.
            BoxStore.shared.change("AI is resting · saved as a box") { $0.addNote(text: said, now: .now) }
            return
        }
        guard !actions.isEmpty else {
            BoxStore.shared.change("Saved as a box") { $0.addNote(text: said, now: .now) }
            return
        }
        for case .answer(let text) in actions {
            BoxStore.shared.answer = text
        }

        var labels: [String] = []
        var undos: [CalendarService.Undo] = []
        for action in actions where action.isCalendarAction {
            do {
                switch action {
                case let .addEvent(title, date, time, minutes):
                    guard let start = CalendarService.date(date, time) else { continue }
                    undos.append(try CalendarService.shared.add(title: title, start: start, minutes: minutes))
                    labels.append("Added ‘\(title)’ · \(Labels.reminder(start))")
                case let .moveEvent(id, date, time):
                    guard let event = calendar.byID[id] else { continue }
                    let keep = CalendarService.time(event.startDate) ?? TimeOfDay(hour: 9, minute: 0)!
                    guard let start = CalendarService.date(date, time ?? keep) else { continue }
                    let title = event.title ?? "event"
                    undos.append(try CalendarService.shared.move(event, to: start))
                    labels.append("Moved ‘\(title)’ · \(Labels.reminder(start))")
                case .cancelEvent(let id):
                    guard let event = calendar.byID[id] else { continue }
                    let title = event.title ?? "event"
                    undos.append(try CalendarService.shared.cancel(event))
                    labels.append("Cancelled ‘\(title)’")
                default:
                    break
                }
            } catch {
                labels.append("Couldn't change Calendar")
            }
        }

        let storeActions = actions.filter(\.isStoreAction)
        let result = Schedule.apply(storeActions, to: store, now: .now)
        for change in result.changes { labels.append(label(change, in: result.store)) }

        let unsupported = actions.filter {
            if case .answer = $0 { return false }
            return !$0.isStoreAction && !$0.isCalendarAction
        }
        var finalStore = result.store
        if labels.isEmpty && BoxStore.shared.answer != nil && unsupported.isEmpty {
            return
        }
        if labels.isEmpty {
            // Only things Friday can't do yet (messages, calls, web): keep what was said as a box.
            finalStore.addNote(text: said, now: .now)
            labels.append(unsupported.isEmpty ? "Saved as a box" : "Saved as a box · can't do that yet")
        }

        let summary = labels.count > 1 ? "\(labels[0]) +\(labels.count - 1)" : labels[0]
        let calendarUndo = undos
        BoxStore.shared.change(summary, onUndo: calendarUndo.isEmpty ? nil : {
            CalendarService.shared.undo(calendarUndo)
        }) { $0 = finalStore }
    }

    private static func label(_ change: Change, in store: Store) -> String {
        switch change {
        case .added(let id): "Added ‘\(store.item(id)?.title ?? "to-do")’"
        case .completed(let id): "Done ‘\(store.item(id)?.title ?? "")’"
        case .uncompleted(let id): "Not done ‘\(store.item(id)?.title ?? "")’"
        case .deleted(let item): "Removed ‘\(item.title)’"
        case .moved(let id, _, _): "Moved ‘\(store.item(id)?.title ?? "")’"
        case .renamed(let id): "Renamed ‘\(store.item(id)?.title ?? "")’"
        case .focused(let id, let on): on ? "Priority ‘\(store.item(id)?.title ?? "")’" : "Not priority"
        case .noted: "Saved as a box"
        case .deletedBox(let note): "Deleted ‘\(Labels.title(of: note))’"
        case .editedBox(let id): "Updated ‘\(store.note(id).map(Labels.title) ?? "box")’"
        }
    }
}
