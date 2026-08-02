import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeEntryDetailsActionSheetPresenter {
  weak var hostViewController: UIViewController?
  let bridge: NativeEntryDetailsBridge
  private var isPresentingActionSheet = false

  init(bridge: NativeEntryDetailsBridge) {
    self.bridge = bridge
  }

  func presentMarkCompleted(entryID: String) {
    presentActionSheet(
      title: "Mark as completed?",
      message: "This will set the remaining balance to zero.",
      confirmTitle: "Mark Completed",
      confirmStyle: .default
    ) { [weak self] in
      self?.bridge.perform(action: .markCompleted, id: entryID)
    }
  }

  func presentDelete(entryID: String) {
    presentActionSheet(
      title: "Delete this entry?",
      message: "You can restore it later from Trash.",
      confirmTitle: "Delete Entry",
      confirmStyle: .destructive
    ) { [weak self] in
      self?.bridge.perform(action: .delete, id: entryID)
    }
  }

  private func presentActionSheet(
    title: String,
    message: String,
    confirmTitle: String,
    confirmStyle: UIAlertAction.Style,
    onConfirm: @escaping () -> Void
  ) {
    guard !isPresentingActionSheet else { return }
    guard let hostViewController, hostViewController.presentedViewController == nil else { return }
    isPresentingActionSheet = true

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let hostViewController = self.hostViewController,
            hostViewController.presentedViewController == nil,
            hostViewController.viewIfLoaded?.window != nil else {
        self.isPresentingActionSheet = false
        return
      }

      let alert = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .actionSheet
      )
      alert.addAction(
        UIAlertAction(title: confirmTitle, style: confirmStyle) { [weak self] _ in
          self?.isPresentingActionSheet = false
          onConfirm()
        }
      )
      alert.addAction(
        UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
          self?.isPresentingActionSheet = false
        }
      )
      if let popover = alert.popoverPresentationController {
        popover.sourceView = hostViewController.view
        popover.sourceRect = CGRect(
          x: hostViewController.view.bounds.midX,
          y: hostViewController.view.bounds.maxY - 1,
          width: 1,
          height: 1
        )
        popover.permittedArrowDirections = []
      }
      hostViewController.present(alert, animated: true)
    }
  }
}

@available(iOS 26.0, *)
final class NativeEntryDetailsHostController: UIViewController {
  private let bridge: NativeEntryDetailsBridge
  private let hostingController: UIHostingController<NativeEntryDetailsView>
  private let actionSheetPresenter: NativeEntryDetailsActionSheetPresenter

  init(
    bridge: NativeEntryDetailsBridge,
    onBack: @escaping () -> Void,
    onEdit: @escaping (NativeEntryDetailsSnapshot) -> Void
  ) {
    self.bridge = bridge
    let actionSheetPresenter = NativeEntryDetailsActionSheetPresenter(bridge: bridge)
    self.actionSheetPresenter = actionSheetPresenter
    hostingController = UIHostingController(
      rootView: NativeEntryDetailsView(
        bridge: bridge,
        onBack: onBack,
        onEdit: onEdit,
        onRequestMarkCompleted: { entryID in
          actionSheetPresenter.presentMarkCompleted(entryID: entryID)
        },
        onRequestDelete: { entryID in
          actionSheetPresenter.presentDelete(entryID: entryID)
        }
      )
    )
    super.init(nibName: nil, bundle: nil)
    actionSheetPresenter.hostViewController = self
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
