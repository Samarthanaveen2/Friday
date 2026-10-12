import SwiftUI
import UIKit
import XCTest
@testable import Friday

/// Renders every screen state to PNG on the simulator. CI publishes them to the "screens"
/// release so the UI can be reviewed without a Mac.
@MainActor
final class Snapshots: XCTestCase {
    private var folder: URL {
        let path = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory() + "friday-screens"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private let phone = CGSize(width: 393, height: 852)

    private func snap<V: View>(_ name: String, size: CGSize, dark: Bool = false,
                               textSize: DynamicTypeSize = .large, @ViewBuilder _ view: () -> V) throws {
        let root = view()
            .environment(\.dynamicTypeSize, textSize)
            .environment(\.colorScheme, dark ? .dark : .light)
        let host = UIHostingController(rootView: root)
        host.overrideUserInterfaceStyle = dark ? .dark : .light
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        let file = folder.appendingPathComponent("\(name).png")
        try XCTUnwrap(image.pngData()).write(to: file)
        print("SNAPSHOT \(file.path)")
        window.isHidden = true
    }

    // MARK: Sample data

    private let wave: [CGFloat] = (0..<40).map { i in
        let x = Double(i)
        return CGFloat(0.25 + 0.7 * abs(sin(x * 0.55) * cos(x * 0.21)))
    }

    private func home(updated: Bool = false, card: ResultCardModel? = nil, emptyToday: Bool = false) -> HomeModel {
        HomeModel(
            dateLabel: "Sunday, 11 October",
            today: emptyToday ? [
                RowModel(id: "1", title: "Signals lecture", time: "9:00", done: true),
            ] : [
                RowModel(id: "3", title: "See the warden", time: "15:00", priority: true, note: updated ? "New" : nil, highlighted: updated),
                RowModel(id: "4", title: "Reply to project group", time: "16:00", priority: true),
                RowModel(id: "7", title: "DBMS lecture", time: "10:00", calendarColor: .orange),
                RowModel(id: "5", title: "Gym", time: "17:00", note: updated ? "from 14:00" : nil, highlighted: updated),
                RowModel(id: "6", title: "Wash clothes"),
                RowModel(id: "2", title: "Finish lab report", time: "11:30", done: true, note: updated ? "Done" : nil, highlighted: updated),
            ],
            next: ("Project meeting", "Sat 16:00"),
            boxes: [
                BoxModel(id: "m", title: "Money", text: "", kind: .money(lines: [
                    .init(label: "Rahul owes you", amount: "₹150", tone: .positive),
                    .init(label: "You owe Priya", amount: "₹80", tone: .negative),
                    .init(label: "This week", amount: "₹1,240"),
                ]), pinned: true),
                BoxModel(id: "b1", title: "Club fest poster", text: "Blue background, club logo big in the middle. Ask Arjun for the font. Print 40 copies by Thursday.",
                         reminder: updated ? "Thu 18:00" : nil, highlighted: updated, note: updated ? "New" : nil),
                BoxModel(id: "b2", title: "Groceries", text: "- [ ] Chicken\n- [x] Eggs\n- [ ] Vegetables\n- [ ] Paneer 500 g"),
                BoxModel(id: "b3", title: "Hostel wifi", text: "KGP-Hall-5 / password on the notice board near the mess", reminder: nil, color: .sky),
                BoxModel(id: "b4", title: "Startup idea", text: "Mess menu app that lets students vote on tomorrow's dinner. Start with our hall, 20 regulars first.", reminder: "Sun 10:00"),
                BoxModel(id: "b5", title: nil, text: "Gift for mom's birthday — the brass lamp from the market", color: .sand),
            ],
            pill: updated ? "4 changes" : nil,
            card: card
        )
    }

    private func keyboardFrame<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        // Imitates the system keyboard backdrop and the globe/mic row under it.
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                content()
                HStack {
                    Image(systemName: "globe")
                    Spacer()
                    Image(systemName: "mic")
                }
                .font(.system(size: 22))
                .foregroundStyle(Palette.keyText.opacity(0.8))
                .padding(.horizontal, 28)
                .frame(height: 64)
            }
            .background(Palette.dynamic(0xD1D4DA, 0x2B2B2D))
        }
        .ignoresSafeArea()
        .background(Palette.background)
    }

    // MARK: Keyboard

    func testKeyboard() throws {
        let size = CGSize(width: 393, height: 380)
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            try snap("keyboard-idle-\(mode)", size: size, dark: dark) {
                keyboardFrame { KeyboardView(model: KeyboardModel()) }
            }
            try snap("keyboard-recording-\(mode)", size: size, dark: dark) {
                keyboardFrame { KeyboardView(model: KeyboardModel(mode: .recording(seconds: 12), levels: wave)) }
            }
        }
        try snap("keyboard-working-light", size: size) {
            keyboardFrame { KeyboardView(model: KeyboardModel(mode: .working)) }
        }
        try snap("keyboard-done-light", size: size) {
            keyboardFrame { KeyboardView(model: KeyboardModel(tone: "Casual", strip: .info("Done"))) }
        }
        try snap("keyboard-offline-dark", size: size, dark: true) {
            keyboardFrame { KeyboardView(model: KeyboardModel(strip: .warning("No internet — used phone"))) }
        }
        try snap("keyboard-undo-raw-dark", size: size, dark: true) {
            keyboardFrame { KeyboardView(model: KeyboardModel(strip: .undoRaw(hasRaw: true))) }
        }
        try snap("keyboard-pastelast-light", size: size) {
            keyboardFrame { KeyboardView(model: KeyboardModel(strip: .pasteLast)) }
        }
        try snap("keyboard-symbols-dark", size: size, dark: true) {
            keyboardFrame { KeyboardView(model: KeyboardModel(symbolsPage: 1)) }
        }
    }

    // MARK: Home

    func testHome() throws {
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            try snap("home-\(mode)", size: phone, dark: dark) { HomeScreen(model: home()) }
            try snap("home-updated-\(mode)", size: phone, dark: dark) { HomeScreen(model: home(updated: true)) }
        }
        try snap("home-nothing-left-light", size: phone) { HomeScreen(model: home(emptyToday: true)) }
        try snap("home-large-text-light", size: phone, textSize: .xxxLarge) { HomeScreen(model: home()) }
        // First run: nothing saved yet, only the setup box.
        let firstRun = HomeModel(dateLabel: "Monday, 12 October", today: [], next: nil,
                                 boxes: [BoxModel(id: "setup", title: "Finish setup",
                                                  text: "• Add the Friday keyboard (Settings → General → Keyboard) and allow Full Access\n• Paste your free Groq key in Settings",
                                                  highlighted: true)],
                                 pill: nil)
        try snap("home-first-run-light", size: phone) { HomeScreen(model: firstRun) }
        try snap("home-first-run-dark", size: phone, dark: true) { HomeScreen(model: firstRun) }
    }

    func testBoxDetail() throws {
        for dark in [false, true] {
            try snap("box-\(dark ? "dark" : "light")", size: phone, dark: dark) {
                BoxDetailScreen(title: .constant("Club fest poster"),
                                text: .constant("Blue background, club logo big in the middle. Ask Arjun for the font.\n\nPrint 40 copies by Thursday."),
                                reminder: "Thu 16 Oct, 18:00", pinned: true)
            }
        }
        try snap("box-checklist-light", size: phone) {
            BoxDetailScreen(title: .constant("Groceries"),
                            text: .constant("- [ ] Chicken\n- [x] Eggs\n- [ ] Vegetables\n- [ ] Paneer 500 g"))
        }
        try snap("box-new-listening-light", size: phone) {
            BoxDetailScreen(title: .constant(""), text: .constant(""))
        }
    }

    func testCards() throws {
        let answer = ResultCardModel(kind: .answer(text: "Arsenal play Chelsea on Sat 18 Oct at 22:00 (Emirates).", source: "premierleague.com"))
        let ready = ResultCardModel(kind: .ready(title: "WhatsApp to Rahul", preview: "I'll be 10 min late, start without me", button: "Send on WhatsApp", systemImage: "paperplane.fill"))
        let choice = ResultCardModel(kind: .choice(question: "Which Rahul?", options: ["Rahul S", "Rahul K"]))
        try snap("card-answer-light", size: phone) { HomeScreen(model: home(card: answer)) }
        try snap("card-ready-light", size: phone) { HomeScreen(model: home(card: ready)) }
        try snap("card-choice-dark", size: phone, dark: true) { HomeScreen(model: home(card: choice)) }
        var missed = home()
        missed.pill = "Didn't catch that"
        missed.pillUndo = false
        try snap("pill-missed-light", size: phone) { HomeScreen(model: missed) }
    }

    func testTalkPill() throws {
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            var listening = home()
            listening.talk = .listening(Array(wave.prefix(20)))
            try snap("talk-listening-\(mode)", size: phone, dark: dark) { HomeScreen(model: listening) }
        }
        var writing = home()
        writing.talk = .writing
        try snap("talk-writing-light", size: phone) { HomeScreen(model: writing) }
        try snap("box-listening-light", size: phone) {
            BoxDetailScreen(title: .constant("Groceries"), text: .constant("Milk, eggs, paneer"),
                            talk: .listening(Array(wave.prefix(20))))
        }
    }
}
