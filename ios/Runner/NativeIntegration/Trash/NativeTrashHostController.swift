import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeTrashHostController: UIViewController {
  let store = NativeTrashStore()
  private let onBack: () -> Void
  private let onEntrySelected: (String) -> Void
  private let onRestore: (String) -> Void
  private let onDeleteForeverConfirmed: (String) -> Void
  private let onEmptyTrashConfirmed: () -> Void
  private var hostingController: UIHostingController<NativeTrashView>!

  init(
    onBack: @escaping () -> Void,
    onEntrySelected: @escaping (String) -> Void,
    onRestore: @escaping (String) -> Void,
    onDeleteForeverConfirmed: @escaping (String) -> Void,
    onEmptyTrashConfirmed: @escaping () -> Void
  ) {
    self.onBack = onBack
    self.onEntrySelected = onEntrySelected
    self.onRestore = onRestore
    self.onDeleteForeverConfirmed = onDeleteForeverConfirmed
    self.onEmptyTrashConfirmed = onEmptyTrashConfirmed
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    hostingController = UIHostingController(
      rootView: NativeTrashView(
        store: store,
        onBack: onBack,
        onEntrySelected: onEntrySelected,
        onRestore: onRestore,
        onDeleteForever: { [weak self] id in self?.presentDeleteForever(id: id) },
        onEmptyTrash: { [weak self] in self?.presentEmptyTrash() }
      )
    )
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

  func apply(payload: Any?) { store.apply(payload: payload) }
  func setActionInFlight(_ value: Bool) { store.setActionInFlight(value) }

  func presentError(message: String) {
    let alert = UIAlertController(title: "Trash", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }

  private func presentDeleteForever(id: String) {
    guard !store.actionInFlight, presentedViewController == nil else { return }
    let alert = UIAlertController(
      title: "Delete forever?",
      message: "This entry cannot be recovered after deletion.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete Forever", style: .destructive) { [weak self] _ in
      self?.onDeleteForeverConfirmed(id)
    })
    present(alert, animated: true)
  }

  private func presentEmptyTrash() {
    guard !store.actionInFlight, !store.entries.isEmpty, presentedViewController == nil else { return }
    let alert = UIAlertController(
      title: "Empty Trash?",
      message: "This permanently deletes every item currently in Trash.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Empty Trash", style: .destructive) { [weak self] _ in
      self?.onEmptyTrashConfirmed()
    })
    present(alert, animated: true)
  }
}
