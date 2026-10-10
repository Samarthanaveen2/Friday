import UIKit

/// Install-probe keyboard: shows whether it can reach the app (App Group), whether the app's
/// heartbeat is alive, and whether it can open the app. The real voice bar comes later.
final class KeyboardViewController: UIInputViewController {
    private let status = UILabel()
    private var timer: Timer?
    private var opens = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        status.numberOfLines = 0
        status.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        status.textAlignment = .left

        let open = UIButton(type: .system)
        open.setTitle("Open Friday", for: .normal)
        open.addTarget(self, action: #selector(openFriday), for: .touchUpInside)

        let globe = UIButton(type: .system)
        globe.setImage(UIImage(systemName: "globe"), for: .normal)
        globe.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        let buttons = UIStackView(arrangedSubviews: [globe, open])
        buttons.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [status, buttons])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let height = view.heightAnchor.constraint(equalToConstant: 320)
        height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            height,
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        AppGroup.write([
            "t": Date().timeIntervalSince1970,
            "fullAccess": hasFullAccess ? 1 : 0,
            "opens": Double(opens),
        ], to: "keyboard.json")

        let hb = AppGroup.read("heartbeat.json")
        let folder = AppGroup.containerURL == nil ? "❌ missing" : "✅ ok"
        let access = hasFullAccess ? "✅ on" : "❌ off"
        let app: String
        if let hb {
            let alive = (hb["running"] == 1) ? "🟢 running" : "⚪️ stopped"
            app = "\(alive), last beat \(AppGroup.ageText(hb["t"]))"
        } else {
            app = "no heartbeat yet"
        }
        status.text = """
        Shared folder: \(folder)
        Full Access:   \(access)
        Friday app:    \(app)
        \(AppGroup.diagnostics)
        """
    }

    /// Keyboards cannot call UIApplication.open directly. This finds the app object through the
    /// responder chain and calls its open-URL method by name (works on current iOS versions).
    @objc private func openFriday() {
        guard let url = URL(string: "friday://probe") else { return }
        opens += 1
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        typealias OpenFunction = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, AnyObject?) -> Void
        while let r = responder {
            if r.responds(to: selector) {
                let imp = r.method(for: selector)
                let call = unsafeBitCast(imp, to: OpenFunction.self)
                call(r, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = r.next
        }
    }
}
