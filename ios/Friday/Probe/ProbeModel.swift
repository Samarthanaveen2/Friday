import ActivityKit
import FoundationModels
import FridayCore
import Observation
import Security
import Speech
import UIKit

/// One line of the install-probe report.
struct Check: Identifiable, Sendable {
    enum Status: Sendable { case pass, fail, waiting }

    let id: String
    let title: String
    let status: Status
    let detail: String
    var hint: String? = nil
}

struct CheckSection: Identifiable, Sendable {
    let id: String
    let checks: [Check]
}

/// Gathers everything the probe needs to tell us about free signing on this phone.
@MainActor
@Observable
final class ProbeModel {
    private(set) var keyboard: KeyboardBeat?
    private(set) var intentRun: IntentRun?
    private(set) var openedFromKeyboardAt: Date?
    private(set) var speechNote = "Checking…"
    private(set) var speechOK: Bool?
    private(set) var now = Date.now

    private let profile = GroupStore.embeddedProfile()
    private let group = GroupStore.shared
    private let keychainOK = ProbeModel.keychainRoundTrip()
    private let defaults = UserDefaults.standard

    init() {
        openedFromKeyboardAt = defaults.object(forKey: "probe.openedFromKeyboard") as? Date
    }

    func refresh() {
        now = .now
        keyboard = group.read(KeyboardBeat.self, from: ProbeFile.keyboard)
        intentRun = group.read(IntentRun.self, from: ProbeFile.intent)
    }

    func handle(_ url: URL) {
        guard url.scheme == "friday" else { return }
        let from = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "from" })?.value
        if from == "keyboard" {
            openedFromKeyboardAt = .now
            defaults.set(openedFromKeyboardAt, forKey: "probe.openedFromKeyboard")
            Haptics.success()
        }
        if url.host == "session" {
            Task {
                await Session.shared.start(source: from == "intent" ? .app : .keyboard)
                if from == "intent" {
                    // Opened by the widget-extension fallback: record that the mic did start.
                    self.group.write(IntentRun(at: .now, ranIn: .widget, micStarted: Session.shared.running, appWasActive: true),
                                to: ProbeFile.intent)
                    self.refresh()
                }
            }
        }
    }

    func checkSpeech() async {
        let locales = await SpeechTranscriber.supportedLocales
        let ids = locales.map { $0.identifier(.bcp47) }
        if ids.contains("en-IN") {
            speechOK = true
            speechNote = "Indian English supported"
        } else if ids.contains("en-US") {
            speechOK = true
            speechNote = "US English (no Indian English model)"
        } else {
            speechOK = false
            speechNote = ids.isEmpty ? "No on-device speech" : "English not found"
        }
    }

    // MARK: Report

    var sections: [CheckSection] {
        let session = Session.shared
        return [
            CheckSection(id: "Signing", checks: [signingCheck, groupCheck, keychainCheck]),
            CheckSection(id: "Keyboard", checks: [keyboardSeenCheck, fullAccessCheck, roundTripCheck, openAppCheck]),
            CheckSection(id: "Mic", checks: [micCheck(session), backgroundCheck(session), sessionTestCheck(session),
                                             recoveryCheck(session), speechToTextCheck]),
            CheckSection(id: "Start without opening Friday", checks: [intentCheck, activityCheck(session)]),
            CheckSection(id: "On-device AI", checks: [speechCheck, appleAICheck]),
        ]
    }

    var reportText: String {
        let lines = sections.flatMap { section in
            ["[\(section.id)]"] + section.checks.map { check in
                let mark: String
                switch check.status {
                case .pass: mark = "✓"
                case .fail: mark = "✕"
                case .waiting: mark = "…"
                }
                return "\(mark) \(check.title): \(check.detail)"
            }
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        return (["Friday probe \(version) · iOS \(UIDevice.current.systemVersion)"] + lines).joined(separator: "\n")
    }

    private var signingCheck: Check {
        guard let profile else {
            return Check(id: "sign", title: "Signed by SideStore", status: .fail, detail: "No signing profile found")
        }
        let days = profile.daysLeft(now: now).map { "\($0) days left" } ?? "expiry unknown"
        return Check(id: "sign", title: "Signed by SideStore", status: .pass,
                     detail: "Team \(profile.teamID ?? "?") · \(days)")
    }

    private var groupCheck: Check {
        if let id = group.groupID {
            return Check(id: "group", title: "Shared folder (App Group)", status: .pass, detail: id)
        }
        let tried = group.tried.map(\.name).joined(separator: ", ")
        return Check(id: "group", title: "Shared folder (App Group)", status: .fail,
                     detail: tried.isEmpty ? "Nothing to try" : "Tried \(tried)")
    }

    private var keychainCheck: Check {
        Check(id: "keychain", title: "Keychain (for API keys)", status: keychainOK ? .pass : .fail,
              detail: keychainOK ? "Saves and reads" : "Blocked")
    }

    private var keyboardSeenCheck: Check {
        guard let keyboard else {
            return Check(id: "kb", title: "Friday keyboard", status: .waiting, detail: "Not seen yet",
                         hint: "Settings → General → Keyboard → Keyboards → Add → Friday. Then open it in any app.")
        }
        return Check(id: "kb", title: "Friday keyboard", status: .pass,
                     detail: "Seen \(ageLabel(now.timeIntervalSince(keyboard.at)))")
    }

    private var fullAccessCheck: Check {
        guard let keyboard else {
            return Check(id: "fa", title: "Full Access", status: .waiting, detail: "Open the keyboard first")
        }
        return Check(id: "fa", title: "Full Access", status: keyboard.fullAccess ? .pass : .fail,
                     detail: keyboard.fullAccess ? "On" : "Off",
                     hint: keyboard.fullAccess ? nil : "Settings → General → Keyboard → Keyboards → Friday → Allow Full Access.")
    }

    private var roundTripCheck: Check {
        let ok = keyboard?.roundTrip == true
        return Check(id: "rt", title: "Keyboard ↔ app messages", status: ok ? .pass : .waiting,
                     detail: ok ? "Round trip works" : "Not tested",
                     hint: ok ? nil : "With the mic on, tap Ping on the Friday keyboard.")
    }

    private var openAppCheck: Check {
        guard let at = openedFromKeyboardAt else {
            return Check(id: "open", title: "Keyboard opens Friday", status: .waiting, detail: "Not tested",
                         hint: "Tap Open Friday on the keyboard.")
        }
        return Check(id: "open", title: "Keyboard opens Friday", status: .pass,
                     detail: "Worked \(ageLabel(now.timeIntervalSince(at)))")
    }

    private func micCheck(_ session: Session) -> Check {
        if let error = session.lastError {
            return Check(id: "mic", title: "Mic", status: .fail, detail: error)
        }
        return Check(id: "mic", title: "Mic", status: session.running ? .pass : .waiting,
                     detail: session.running ? "Listening" : "Off — tap the mic above")
    }

    private func sessionTestCheck(_ session: Session) -> Check {
        guard let recording = session.lastRecording else {
            return Check(id: "test", title: "Dictation test", status: .waiting, detail: "Not tested",
                         hint: "Use the Session test card above.")
        }
        let detail = String(format: "%.1f s, pre-roll %.1f s, %@", recording.duration, session.lastPreRollSeconds,
                            recording.hasSpeech ? "speech heard" : "no speech heard")
        return Check(id: "test", title: "Dictation test", status: recording.hasSpeech ? .pass : .fail, detail: detail)
    }

    private var speechToTextCheck: Check {
        let hasKey = Keys.get(.groq) != nil
        guard let outcome = DictationPipeline.shared.last else {
            return Check(id: "stt", title: "Speech to text", status: .waiting,
                         detail: hasKey ? "Groq key saved · not tested" : "No Groq key · phone only",
                         hint: "Dictate in the Session test card.")
        }
        return Check(id: "stt", title: "Speech to text", status: outcome.nothing ? .fail : .pass,
                     detail: outcome.nothing ? "Didn't catch that · \(outcome.timings.line)" : outcome.timings.line)
    }

    private func recoveryCheck(_ session: Session) -> Check {
        let n = session.recoveries
        return Check(id: "recover", title: "Came back after a call", status: n > 0 ? .pass : .waiting,
                     detail: n > 0 ? "\(n) time\(n == 1 ? "" : "s")" : "Not tested",
                     hint: n > 0 ? nil : "With a session on, take or make a call, then hang up.")
    }

    private func backgroundCheck(_ session: Session) -> Check {
        let best = session.bestBackgroundSeconds
        let ok = best >= 120
        return Check(id: "bg", title: "Mic stays on in other apps", status: ok ? .pass : .waiting,
                     detail: best == 0 ? "Not tested" : "Lasted \(best / 60)m \(best % 60)s",
                     hint: ok ? nil : "Turn the mic on, use another app for 2 minutes, then come back.")
    }

    private var intentCheck: Check {
        let title = "Action button / Control Center"
        guard let run = intentRun else {
            return Check(id: "intent", title: title, status: .waiting, detail: "Not tested",
                         hint: "Action button → Controls → Start Friday (or Shortcut → Start Friday). Close Friday, then press it.")
        }
        let age = ageLabel(now.timeIntervalSince(run.at))
        switch run.ranIn {
        case .app where run.micStarted && !run.appWasActive:
            return Check(id: "intent", title: title, status: .pass,
                         detail: "Mic started without opening Friday · \(age)")
        case .app where run.appWasActive:
            return Check(id: "intent", title: title, status: .waiting,
                         detail: "Ran while Friday was open · \(age)",
                         hint: "Swipe Friday away from the app switcher, then press it again.")
        case .app:
            return Check(id: "intent", title: title, status: .fail, detail: "Ran, but the mic didn't start · \(age)")
        case .widget:
            return Check(id: "intent", title: title, status: .fail,
                         detail: run.micStarted ? "Had to open Friday to start the mic · \(age)"
                                                : "Ran in the widget; Friday didn't open · \(age)",
                         hint: "Try the other setup: Action button → Shortcut → Start Friday.")
        }
    }

    private func activityCheck(_ session: Session) -> Check {
        if session.activityRunning {
            return Check(id: "la", title: "Live Activity", status: .pass, detail: "Showing “Friday on”")
        }
        if let note = session.activityNote {
            return Check(id: "la", title: "Live Activity", status: .fail, detail: note)
        }
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        return Check(id: "la", title: "Live Activity", status: enabled ? .waiting : .fail,
                     detail: enabled ? "Shows when the mic is on" : "Turned off in Settings")
    }

    private var speechCheck: Check {
        Check(id: "speech", title: "On-device speech",
              status: speechOK.map { $0 ? Check.Status.pass : Check.Status.fail } ?? .waiting, detail: speechNote)
    }

    private var appleAICheck: Check {
        switch SystemLanguageModel.default.availability {
        case .available:
            return Check(id: "fm", title: "Apple Intelligence model", status: .pass, detail: "Ready (offline backup)")
        case .unavailable(let reason):
            return Check(id: "fm", title: "Apple Intelligence model", status: .fail, detail: "\(reason)")
        }
    }

    // MARK: Keychain

    nonisolated private static func keychainRoundTrip() -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.samarth.friday.probe",
            kSecAttrAccount as String: "probe",
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data("ok".utf8)
        guard SecItemAdd(add as CFDictionary, nil) == errSecSuccess else { return false }
        var query = base
        query[kSecReturnData as String] = true
        var out: CFTypeRef?
        let ok = SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess && (out as? Data) == Data("ok".utf8)
        SecItemDelete(base as CFDictionary)
        return ok
    }
}
