import SwiftUI
import UIKit

/// Hosts the SwiftUI keyboard (FridayUI KeyboardView) and hands it the text field.
final class KeyboardViewController: UIInputViewController {
    private let controller = KeyboardController()

    override func viewDidLoad() {
        super.viewDidLoad()
        controller.input = self
        let host = UIHostingController(rootView: KeyboardRoot(controller: controller))
        host.view.backgroundColor = .clear
        host.safeAreaRegions = []
        addChild(host)
        view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        let height = view.heightAnchor.constraint(equalToConstant: KeyboardView.height)
        height.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            height,
        ])
        host.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.appeared()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.disappeared()
    }
}

private struct KeyboardRoot: View {
    let controller: KeyboardController

    var body: some View {
        KeyboardView(model: controller.model, actions: controller.actions)
    }
}
