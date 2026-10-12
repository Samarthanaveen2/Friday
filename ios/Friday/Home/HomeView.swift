import FridayCore
import SwiftUI
import UIKit

/// The app's main screen (PLAN §3): Today strip, boxes, mic. Maps the saved store onto the
/// FridayUI screens and handles navigation, talking, reminders and Settings.
struct HomeView: View {
    let probe: ProbeModel
    @State private var boxes = BoxStore.shared
    @State private var talk = Talk.shared
    @State private var session = Session.shared
    @State private var path: [String] = []
    @State private var showSettings = false
    @State private var showSearch = false
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
                       onNew: newBox,
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
        var rows = (layout.focus + layout.also).map { item in
            RowModel(id: item.id, title: item.title, time: item.time?.description, done: item.done, priority: item.focus)
        }
        rows += store.reminders(on: today, in: zone).map { note in
            RowModel(id: "r:" + note.id, title: Labels.title(of: note), time: note.reminder.map(Labels.time))
        }
        let next = layout.next.map { item in
            (title: item.title, when: Labels.day(item.date, today: today) + (item.time.map { " \($0)" } ?? ""))
        }
        var cards = store.boxesInOrder.map { note in
            BoxModel(id: note.id, title: note.title, text: note.text,
                     reminder: note.reminder.map { Labels.reminder($0) }, pinned: note.pinned)
        }
        if let setup = setupBox { cards.insert(setup, at: 0) }
        return HomeModel(dateLabel: Labels.header(.now), today: rows, next: next, boxes: cards,
                         pill: boxes.pill, pillUndo: boxes.canUndo,
                         // Mic levels are only read while this place is listening: reading them always
                         // would redraw Home 20 times a second whenever the session is on.
                         talk: talk.state(for: .newBox, levels: talk.target == .newBox ? session.levels : []))
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
    @State private var confirmDelete = false

    var body: some View {
        let note = boxes.store.note(id)
        BoxDetailScreen(title: binding(\.title), text: textBinding,
                        reminder: note?.reminder.map { Labels.reminder($0, long: true) },
                        pinned: note?.pinned ?? false,
                        talk: talk.state(for: .box(id), levels: talk.target == .box(id) ? session.levels : []),
                        onBack: onBack,
                        onPin: { Haptics.tap(); boxes.change { $0.togglePin(id) } },
                        onMenu: { confirmDelete = true },
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
            .confirmationDialog("Delete this box?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete box", role: .destructive) {
                    onBack()
                    boxes.change("Box deleted") { $0.deleteNote(id) }
                }
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
