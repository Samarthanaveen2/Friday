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
        let root = view().environment(\.dynamicTypeSize, textSize)
        let host = UIHostingController(rootView: root)
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

    private func today(updated: Bool = false, card: ResultCardModel? = nil, emptyFocus: Bool = false) -> TodayModel {
        TodayModel(
            dateLabel: "Sunday, 11 October",
            focus: emptyFocus ? [] : [
                RowModel(id: "1", title: "Signals lecture", time: "9:00", done: true),
                RowModel(id: "2", title: "Finish lab report", time: "11:30", done: updated, note: updated ? "Done" : nil, highlighted: updated),
                RowModel(id: "3", title: "See the warden", time: "15:00", note: updated ? "New" : nil, highlighted: updated),
                RowModel(id: "4", title: "Reply to project group", time: "16:00"),
            ],
            also: [
                RowModel(id: "5", title: "Gym", time: "17:00", note: updated ? "from 14:00" : nil, highlighted: updated),
                RowModel(id: "6", title: "Wash clothes", note: updated ? "→ Sun" : nil, highlighted: updated),
                RowModel(id: "7", title: "DBMS lecture", time: "10:00", calendarColor: .orange),
                RowModel(id: "8", title: "Call home", time: "18:00"),
            ],
            next: ("Project meeting", "Sat 16:00"),
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
        try snap("keyboard-pastelast-light", size: size) {
            keyboardFrame { KeyboardView(model: KeyboardModel(strip: .pasteLast)) }
        }
        try snap("keyboard-symbols-dark", size: size, dark: true) {
            keyboardFrame { KeyboardView(model: KeyboardModel(symbolsPage: 1)) }
        }
    }

    // MARK: Today

    func testToday() throws {
        for dark in [false, true] {
            let mode = dark ? "dark" : "light"
            try snap("today-\(mode)", size: phone, dark: dark) {
                TodayScreen(model: today(), tab: .constant(.today))
            }
            try snap("today-updated-\(mode)", size: phone, dark: dark) {
                TodayScreen(model: today(updated: true), tab: .constant(.today))
            }
        }
        try snap("today-empty-focus-light", size: phone) {
            TodayScreen(model: today(emptyFocus: true), tab: .constant(.today))
        }
        try snap("today-large-text-light", size: phone, textSize: .xxxLarge) {
            TodayScreen(model: today(), tab: .constant(.today))
        }
    }

    func testCards() throws {
        let answer = ResultCardModel(kind: .answer(text: "Arsenal play Chelsea on Sat 18 Oct at 22:00 (Emirates).", source: "premierleague.com"))
        let ready = ResultCardModel(kind: .ready(title: "WhatsApp to Rahul", preview: "I'll be 10 min late, start without me", button: "Send on WhatsApp", systemImage: "paperplane.fill"))
        let choice = ResultCardModel(kind: .choice(question: "Which Rahul?", options: ["Rahul S", "Rahul K"]))
        try snap("card-answer-light", size: phone) { TodayScreen(model: today(card: answer), tab: .constant(.today)) }
        try snap("card-ready-light", size: phone) { TodayScreen(model: today(card: ready), tab: .constant(.today)) }
        try snap("card-choice-dark", size: phone, dark: true) { TodayScreen(model: today(card: choice), tab: .constant(.today)) }
        var missed = today()
        missed.pill = "Didn't catch that"
        missed.pillUndo = false
        try snap("pill-missed-light", size: phone) { TodayScreen(model: missed, tab: .constant(.today)) }
    }

    func testTalkingSheet() throws {
        let words = "Done with the lab report. Warden wants to see me at 3, push gym to five, laundry Sunday. Priority today: warden and the group reply"
        for dark in [false, true] {
            try snap("talking-\(dark ? "dark" : "light")", size: phone, dark: dark) {
                ZStack(alignment: .bottom) {
                    TodayScreen(model: today(), tab: .constant(.today)).opacity(0.35)
                    TalkingSheet(transcript: words, levels: Array(wave.prefix(28)))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}
