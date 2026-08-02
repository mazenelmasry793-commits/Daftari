import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeEntryDetailsHostController: UIViewController {
  private let bridge: NativeEntryDetailsBridge
  private let hostingController: UIHostingController<NativeEntryDetailsView>

  init(bridge: NativeEntryDetailsBridge, onBack: @escaping () -> Void) {
    self.bridge = bridge
    hostingController = UIHostingController(
      rootView: NativeEntryDetailsView(bridge: bridge, onBack: onBack)
    )
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    hostingController.didMove(toParent: self)
  }

  func showEntry(id: String) { bridge.load(id: id) }
}
