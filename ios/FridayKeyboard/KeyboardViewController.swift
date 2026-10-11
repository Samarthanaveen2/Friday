import FridayCore
import UIKit

/// Install-probe keyboard: proves the keyboard can see the App Group, talk to the app,
/// see the app's live mic, open the app, and type. The real voice bar comes in a later phase.
final class KeyboardViewController: UIInputViewController {
    private let store = GroupStore.shared
    private let statusLabel = UILabel()
    private var ping = 0
    private var roundTrip = false
    private var timer: Timer?
    private var openNote: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        DarwinNotice.observe(ProbeNotice.appBeat)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: Notification.Name(ProbeNotice.appBeat), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        writeBeat()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    // MARK: UI

    private func buildUI() {
        let title = UILabel()
        title.text = "Friday · setup check"
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .secondaryLabel

        statusLabel.numberOfLines = 0
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .label

        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Ping", #selector(pingApp)),
            makeButton("Open Friday", #selector(openFriday)),
            makeButton("Type test", #selector(typeTest)),
        ])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 8
        if needsInputModeSwitchKey {
            let globe = UIButton(type: .system)
            globe.setImage(UIImage(systemName: "globe"), for: .normal)
            globe.tintColor = .label
            globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
            bottom.addArrangedSubview(globe)
        }
        bottom.addArrangedSubview(UIView())
        bottom.addArrangedSubview(makeButton("⌫", #selector(backspace), width: 56))

        let stack = UIStackView(arrangedSubviews: [title, statusLabel, buttons, bottom])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -8),
            view.heightAnchor.constraint(equalToConstant: 250),
        ])
    }

    private func makeButton(_ title: String, _ action: Selector, width: CGFloat? = nil) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = .systemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        config.buttonSize = .medium
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        if let width { button.widthAnchor.constraint(equalToConstant: width).isActive = true }
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    // MARK: Status

    @objc private func refresh() {
        var lines: [String] = []
        lines.append("Full Access: \(hasFullAccess ? "on ✓" : "off ✕")")
        if let id = store.groupID {
            lines.append("Shared folder: ✓ \(id)")
        } else {
            lines.append("Shared folder: ✕ (tried \(store.tried.count))")
        }
        if let beat = store.read(AppBeat.self, from: ProbeFile.app) {
            let age = ageLabel(Date.now.timeIntervalSince(beat.at))
            let mic = beat.micRunning ? "mic live \(meter(beat.level))" : "mic off"
            lines.append("App: \(mic) · \(age)")
            if ping > 0, beat.lastPingSeen == ping, !roundTrip {
                roundTrip = true
                writeBeat()
            }
        } else {
            lines.append("App: not seen yet")
        }
        lines.append("Round trip: \(roundTrip ? "✓" : ping > 0 ? "waiting…" : "tap Ping")")
        if let openNote { lines.append(openNote) }
        statusLabel.text = lines.joined(separator: "\n")
    }

    private func meter(_ level: Float) -> String {
        String(repeating: "▮", count: max(1, Int(level * 6)))
    }

    private func writeBeat() {
        store.write(KeyboardBeat(at: .now, fullAccess: hasFullAccess, ping: ping, roundTrip: roundTrip),
                    to: ProbeFile.keyboard)
    }

    // MARK: Actions

    @objc private func pingApp() {
        UIDevice.current.playInputClick()
        ping = Int(Date.now.timeIntervalSince1970) % 1_000_000
        roundTrip = false
        writeBeat()
        DarwinNotice.post(ProbeNotice.keyboardPing)
        refresh()
    }

    @objc private func openFriday() {
        guard let url = URL(string: "friday://probe?from=keyboard") else { return }
        // Keyboards can't call UIApplication.open directly. Find the app object (responder chain,
        // then sharedApplication via the runtime) and call open through the Objective-C runtime.
        guard let app = applicationObject() else {
            openNote = "Open: no app object ✕"
            refresh()
            return
        }
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard app.responds(to: selector) else {
            openNote = "Open: method missing ✕"
            refresh()
            return
        }
        typealias OpenURL = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        let open = unsafeBitCast(app.method(for: selector), to: OpenURL.self)
        open(app, selector, url as NSURL, NSDictionary(), nil)
        openNote = "Open: asked iOS (\(foundVia))"
        refresh()
    }

    private var foundVia = ""

    private func applicationObject() -> NSObject? {
        var responder: UIResponder? = self
        while let current = responder {
            if let app = current as? UIApplication {
                foundVia = "chain"
                return app
            }
            responder = current.next
        }
        let selector = NSSelectorFromString("sharedApplication")
        if UIApplication.responds(to: selector),
           let app = UIApplication.perform(selector)?.takeUnretainedValue() as? NSObject {
            foundVia = "shared"
            return app
        }
        return nil
    }

    @objc private func typeTest() {
        textDocumentProxy.insertText("Friday works ")
    }

    @objc private func backspace() {
        textDocumentProxy.deleteBackward()
    }
}
