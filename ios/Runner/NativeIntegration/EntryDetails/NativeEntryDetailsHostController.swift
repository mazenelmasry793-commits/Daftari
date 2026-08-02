import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeEntryDetailsAlertPresenter {
  weak var hostViewController: UIViewController?
  let bridge: NativeEntryDetailsBridge
  private var isPresentingAlert = false

  init(bridge: NativeEntryDetailsBridge) {
    self.bridge = bridge
  }

  func presentMarkCompleted(entryID: String) {
    presentAlert(
      title: "Mark as completed?",
      message: "This will set the remaining balance to zero.",
      confirmTitle: "Mark Completed",
      confirmStyle: .default
    ) { [weak self] in
      self?.bridge.perform(action: .markCompleted, id: entryID)
    }
  }

  func presentDelete(entryID: String) {
    presentAlert(
      title: "Delete this entry?",
      message: "You can restore it later from Trash.",
      confirmTitle: "Delete Entry",
      confirmStyle: .destructive
    ) { [weak self] in
      self?.bridge.perform(action: .delete, id: entryID)
    }
  }

  func presentDeletePayment(entryID: String, paymentID: Int) {
    presentAlert(
      title: "Delete this payment?",
      message: "This payment will be removed from the entry.",
      confirmTitle: "Delete Payment",
      confirmStyle: .destructive
    ) { [weak self] in
      self?.bridge.perform(
        action: .deletePayment,
        id: entryID,
        paymentID: paymentID
      )
    }
  }

  private func presentAlert(
    title: String,
    message: String,
    confirmTitle: String,
    confirmStyle: UIAlertAction.Style,
    onConfirm: @escaping () -> Void
  ) {
    guard !isPresentingAlert else { return }
    guard let hostViewController, hostViewController.presentedViewController == nil else { return }
    isPresentingAlert = true

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      guard let hostViewController = self.hostViewController,
            hostViewController.presentedViewController == nil,
            hostViewController.viewIfLoaded?.window != nil else {
        self.isPresentingAlert = false
        return
      }

      let alert = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .alert
      )
      alert.addAction(
        UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
          self?.isPresentingAlert = false
        }
      )
      alert.addAction(
        UIAlertAction(title: confirmTitle, style: confirmStyle) { [weak self] _ in
          self?.isPresentingAlert = false
          onConfirm()
        }
      )
      hostViewController.present(alert, animated: true)
    }
  }
}

@available(iOS 26.0, *)
final class NativeEntryDetailsHostController: UIViewController {
  private let bridge: NativeEntryDetailsBridge
  private let hostingController: UIHostingController<NativeEntryDetailsView>
  private let alertPresenter: NativeEntryDetailsAlertPresenter

  init(
    bridge: NativeEntryDetailsBridge,
    onBack: @escaping () -> Void,
    onEdit: @escaping (NativeEntryDetailsSnapshot) -> Void
  ) {
    self.bridge = bridge
    let alertPresenter = NativeEntryDetailsAlertPresenter(bridge: bridge)
    self.alertPresenter = alertPresenter
    hostingController = UIHostingController(
      rootView: NativeEntryDetailsView(
        bridge: bridge,
        onBack: onBack,
        onEdit: onEdit,
        onRequestMarkCompleted: { entryID in
          alertPresenter.presentMarkCompleted(entryID: entryID)
        },
        onRequestDelete: { entryID in
          alertPresenter.presentDelete(entryID: entryID)
        },
        onRequestDeletePayment: { entryID, paymentID in
          alertPresenter.presentDeletePayment(
            entryID: entryID,
            paymentID: paymentID
          )
        }
      )
    )
    super.init(nibName: nil, bundle: nil)
    alertPresenter.hostViewController = self
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
