import FridayCore
import EventKit
import SwiftUI
import UIKit

/// The app's main screen (PLAN §3): Today strip, boxes, mic. Maps the saved store onto the
/// FridayUI screens and handles navigation, talking, reminders and Settings.
struct HomeView: View {
    let probe: ProbeModel
    @State private var boxes = BoxStore.shared
    @State private var talk = Talk.shared
    @State private var session = Session.shared
    @State private var calendar = CalendarService.shared
    @State private var path: [String] = []
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var reminderFor: String?
    @Namespace private var zoom

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(model: model,
                       onToggle: toggle,
                       onOpenBox: open,
                       onTalk: { talk.start(.newBox) },
                       onCancelTalk: { talk.cancel() },
                       onDoneTalk: { talk.done() },
                       onUndo: { boxes.undo() },
                       onSearch: { showSearch = true },
                       onSettings: { showSettings = true },
                       onCloseCard: { boxes.answer = nil },
                       onNew: newBox,
                       onPower: power,
                       onBoxAction: act,
                       zoom: zoom)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: String.self) { id in
                    BoxDetailHost(id: id, onBack: { if !path.isEmpty { path.removeLast() } })
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationTransition(.zoom(sourceID: id, in: zoom))
                }
        }
        .task { probe.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            probe.refresh()
        }
        .sheet(isPresented: $showSettings, onDismiss: { probe.refresh() }) {
            NavigationStack { SettingsView(probe: probe) }
        }
        .sheet(item: Binding(get: { reminderFor.map(ReminderTarget.init) }, set: { reminderFor = $0?.id })) { target in
            ReminderSheet(initial: boxes.store.note(target.id)?.reminder) { date in
                reminderFor = nil
                boxes.change(date == nil ? "Reminder removed" : "Reminder set") { $0.setReminder(target.id, date) }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSearch) {
            SearchSheet { id in
                showSearch = false
                path.append(id)
            }
        }
    }

    // MARK: Store -> screen

    private var model: HomeModel {
        let store = boxes.store
        let zone = TimeZone.current
        let today = TimeRules.today(now: .now, in: zone)
        let layout = TodayLayout(store: store, today: today)
        // Friday's to-dos, box reminders and today's calendar events, in time order (untimed last).
        var timed: [(minute: Int, row: RowModel)] = []
        var untimed: [RowModel] = []
        for item in layout.focus + layout.also {
            let at = item.time.flatMap { CalendarService.date(item.date, $0) }
            let row = RowModel(id: item.id, title: item.title, time: at.map(Labels.time), done: item.done, priority: item.focus)
            if let time = item.time { timed.append((time.hour * 60 + time.minute, row)) } else { untimed.append(row) }
        }
        for note in store.reminders(on: today, in: zone) {
            guard let at = note.reminder else { continue }
            timed.append((Labels.minuteOfDay(at), RowModel(id: "r:" + note.id, title: Labels.title(of: note), time: Labels.time(at))))
        }
        for event in calendar.today() {
            let row = RowModel(id: "e:" + (event.eventIdentifier ?? event.title ?? ""), title: event.title ?? "Event",
                               time: event.isAllDay ? nil : Labels.time(event.startDate),
                               calendarColor: event.calendar.map { Color(cgColor: $0.cgColor) } ?? Palette.secondary)
            if event.isAllDay { untimed.insert(row, at: 0) } else { timed.append((Labels.minuteOfDay(event.startDate), row)) }
        }
        let rows = timed.sorted { $0.minute < $1.minute }.map(\.row) + untimed
        let next = layout.next.map { item in
            (title: item.title, when: Labels.day(item.date, today: today) + (item.time.map { " \($0)" } ?? ""))
        }
        var cards = store.boxesInOrder.map { note in
            BoxModel(id: note.id, title: note.title, text: note.text,
                     reminder: note.reminder.map { Labels.reminder($0) }, pinned: note.pinned,
                     color: BoxColor(key: note.color))
        }
        if let setup = setupBox { cards.insert(setup, at: 0) }
        return HomeModel(dateLabel: Labels.header(.now), today: rows, next: next, boxes: cards,
                         pill: boxes.pill, pillUndo: boxes.canUndo,
                         card: boxes.answer.map { ResultCardModel(kind: .answer(text: $0, source: nil)) },
                         // Mic levels are only read while this place is listening: reading them always
                         // would redraw Home 20 times a second whenever the session is on.
                         talk: talk.state(for: .newBox, levels: talk.target == .newBox ? session.levels : []),
                         on: session.running)
    }

    /// The On/Off switch: off stops the mic and the Dynamic Island at once; on starts it again.
    private func power() {
        if session.running {
            talk.cancel()
            session.stop()
        } else {
            Task { await session.start(source: .app) }
        }
    }

    /// First run: what's still missing before Friday works fully. Tapping it opens Settings.
    private var setupBox: BoxModel? {
        var missing: [String] = []
        if probe.keyboard == nil { missing.append("• Add the Friday keyboard (Settings → General → Keyboard) and allow Full Access") }
        if Keys.get(.groq) == nil { missing.append("• Paste your free Groq key in Settings") }
        guard !missing.isEmpty else { return nil }
        return BoxModel(id: "setup", title: "Finish setup", text: missing.joined(separator: "\n"), highlighted: true)
    }

    // MARK: Actions

    private func open(_ id: String) {
        if id == "setup" { showSettings = true } else { path.append(id) }
    }

    private func toggle(_ id: String) {
        Haptics.tap()
        if id.hasPrefix("r:") {
            let noteID = String(id.dropFirst(2))
            boxes.change("Reminder done") { $0.setReminder(noteID, nil) }
        } else {
            boxes.change { $0.toggleItem(id, now: .now) }
        }
    }

    /// Long-press menu on a box.
    private func act(_ id: String, _ action: BoxAction) {
        switch action {
        case .pin:
            let pinned = boxes.store.note(id)?.pinned == true
            boxes.change(pinned ? "Unpinned" : "Pinned") { $0.togglePin(id) }
        case .reminder:
            reminderFor = id
        case .color(let color):
            boxes.change { $0.setColor(id, color.key) }
        case .delete:
            boxes.change("Box deleted") { $0.deleteNote(id) }
        }
    }

    private func newBox() {
        var id = ""
        boxes.change { id = $0.addNote(text: "", now: .now) }
        path.append(id)
    }
}

/// One box, full screen. Edits save as you type; an empty box disappears when you leave.
struct BoxDetailHost: View {
    let id: String
    var onBack: () -> Void
    @State private var boxes = BoxStore.shared
    @State private var talk = Talk.shared
    @State private var session = Session.shared
    @State private var editingReminder = false

    var body: some View {
        let note = boxes.store.note(id)
        BoxDetailScreen(title: binding(\.title), text: textBinding,
                        reminder: note?.reminder.map { Labels.reminder($0, long: true) },
                        pinned: note?.pinned ?? false,
                        color: BoxColor(key: note?.color),
                        talk: talk.state(for: .box(id), levels: talk.target == .box(id) ? session.levels : []),
                        onBack: onBack,
                        onPin: { Haptics.tap(); boxes.change { $0.togglePin(id) } },
                        onAction: { action in
                            switch action {
                            case .color(let color): boxes.change { $0.setColor(id, color.key) }
                            case .delete:
                                onBack()
                                boxes.change("Box deleted") { $0.deleteNote(id) }
                            default: break
                            }
                        },
                        onReminder: { editingReminder = true },
                        onClearReminder: { boxes.change("Reminder removed") { $0.setReminder(id, nil) } },
                        onTalk: { talk.start(.box(id)) },
                        onCancelTalk: { talk.cancel() },
                        onDoneTalk: { talk.done() })
            .sheet(isPresented: $editingReminder) {
                ReminderSheet(initial: note?.reminder) { date in
                    editingReminder = false
                    boxes.change(date == nil ? "Reminder removed" : "Reminder set") { $0.setReminder(id, date) }
                }
                .presentationDetents([.medium, .large])
            }
            .onDisappear {
                if talk.target == .box(id) { talk.cancel() }
                if boxes.store.note(id)?.isBlank == true { boxes.change { $0.deleteNote(id) } }
            }
    }

    private func binding(_ key: KeyPath<Note, String?>) -> Binding<String> {
        Binding(get: { boxes.store.note(id)?[keyPath: key] ?? "" },
                set: { value in
                    let text = boxes.store.note(id)?.text ?? ""
                    boxes.change { $0.editNote(id, title: value, text: text, now: .now) }
                })
    }

    private var textBinding: Binding<String> {
        Binding(get: { boxes.store.note(id)?.text ?? "" },
                set: { value in
                    let title = boxes.store.note(id)?.title
                    boxes.change { $0.editNote(id, title: title, text: value, now: .now) }
                })
    }
}

/// Which box the reminder sheet on Home is for.
struct ReminderTarget: Identifiable {
    let id: String
}

/// Pick a reminder date and time, or remove it.
struct ReminderSheet: View {
    let initial: Date?
    var onSave: (Date?) -> Void
    @State private var date: Date

    init(initial: Date?, onSave: @escaping (Date?) -> Void) {
        self.initial = initial
        self.onSave = onSave
        let soon = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        _date = State(initialValue: initial ?? soon)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("When", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                if initial != nil {
                    Button("Remove reminder", role: .destructive) { onSave(nil) }
                }
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Save") { onSave(date) } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onSave(initial) } }
            }
        }
    }
}

/// Find a box by any words in it.
struct SearchSheet: View {
    var onOpen: (String) -> Void
    @State private var boxes = BoxStore.shared
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(boxes.store.search(query)) { note in
                Button { onOpen(note.id) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Labels.title(of: note)).font(.headline).foregroundStyle(Palette.text)
                        if note.title != nil, !note.text.isEmpty {
                            Text(note.text).font(.subheadline).foregroundStyle(Palette.secondary).lineLimit(2)
                        }
                    }
                }
            }
            .overlay {
                if !query.isEmpty && boxes.store.search(query).isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search boxes")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Dates and titles as Home shows them.
enum Labels {
    static func header(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    static func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Today 18:00", "Tomorrow 9:00", "Thu 18:00", "16 Oct 18:00" (long: "Thu 16 Oct, 18:00").
    static func reminder(_ date: Date, long: Bool = false) -> String {
        let calendar = Calendar.current
        let t = time(date)
        if calendar.isDateInToday(date) { return "Today \(t)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(t)" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day ?? 0
        if long { return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) + ", " + t }
        if (0..<7).contains(days) { return date.formatted(.dateTime.weekday(.abbreviated)) + " " + t }
        return date.formatted(.dateTime.day().month(.abbreviated)) + " " + t
    }

    static func day(_ day: Day, today: Day) -> String {
        let gap = today.days(until: day)
        if gap == 1 { return "Tomorrow" }
        var comps = DateComponents()
        comps.year = day.year
        comps.month = day.month
        comps.day = day.day
        guard let date = Calendar.current.date(from: comps) else { return day.description }
        return gap < 7 ? date.formatted(.dateTime.weekday(.abbreviated)) : date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func title(of note: Note) -> String {
        if let title = note.title, !title.isEmpty { return title }
        let first = note.text.split(separator: "\n").first.map(String.init) ?? ""
        return first.isEmpty ? "Empty box" : String(first.prefix(60))
    }
}

// Hiding the navigation bar also turns off the swipe-back gesture; this brings it back.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
