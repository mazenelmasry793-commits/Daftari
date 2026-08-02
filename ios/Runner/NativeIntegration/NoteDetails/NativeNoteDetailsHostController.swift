import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeNoteDetailsDeletePresenter {
  weak var host: UIViewController?
  let bridge: NativeNoteDetailsBridge
  private var presenting = false

  init(bridge: NativeNoteDetailsBridge) { self.bridge = bridge }

  func present(entryID: String) {
    guard !presenting else { return }
    guard let host, host.presentedViewController == nil else { return }
    presenting = true
    DispatchQueue.main.async { [weak self] in
      guard let self, let host = self.host, host.presentedViewController == nil else {
        self?.presenting = false
        return
      }
      let alert = UIAlertController(
        title: "Delete this note?",
        message: "You can restore it later from Trash.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
        self?.presenting = false
      })
      alert.addAction(UIAlertAction(title: "Delete Note", style: .destructive) { [weak self] _ in
        self?.presenting = false
        self?.bridge.perform(action: .delete, id: entryID)
      })
      host.present(alert, animated: true)
    }
  }
}

@available(iOS 26.0, *)
final class NativeNoteDetailsHostController: UIViewController {
  private let bridge: NativeNoteDetailsBridge
  private let hostingController: UIHostingController<NativeNoteDetailsView>
  private let deletePresenter: NativeNoteDetailsDeletePresenter

  init(bridge: NativeNoteDetailsBridge, onBack: @escaping () -> Void) {
    self.bridge = bridge
    let deletePresenter = NativeNoteDetailsDeletePresenter(bridge: bridge)
    self.deletePresenter = deletePresenter
    hostingController = UIHostingController(
      rootView: NativeNoteDetailsView(
        bridge: bridge,
        onBack: onBack,
        onDelete: { id in deletePresenter.present(entryID: id) }
      )
    )
    super.init(nibName: nil, bundle: nil)
    deletePresenter.host = self
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

  func showNote(id: String) { bridge.load(id: id) }
}
