import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeEntriesHostController: UIViewController {
  private let hostingController: UIHostingController<NativeEntriesView>

  init(
    store: NativeEntriesStore,
    type: NativeEntryListType,
    onAdd: @escaping () -> Void,
    onSettings: @escaping () -> Void,
    onEntrySelected: @escaping (String) -> Void
  ) {
    hostingController = UIHostingController(
      rootView: NativeEntriesView(
        store: store,
        type: type,
        onAdd: onAdd,
        onSettings: onSettings,
        onEntrySelected: onEntrySelected
      )
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
}
