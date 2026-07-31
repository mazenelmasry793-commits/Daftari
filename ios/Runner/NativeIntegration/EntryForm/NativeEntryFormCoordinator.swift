import Flutter
import UIKit

final class NativeEntryFormCoordinator {
  private weak var presentedNavigationController: UINavigationController?
  private var presentationDelegate: PresentationDelegate?
  private var isPresented = false

  func present(type: String, from presenter: UIViewController, messenger: FlutterBinaryMessenger) -> Bool {
    guard !isPresented, let entryType = NativeEntryFormType(rawValue: type) else { return false }
    isPresented = true

    let formViewController = NativeEntryFormViewController(
      entryType: entryType,
      onSubmit: { [weak self] payload, completion in
      let channel = FlutterMethodChannel(
        name: NativeChannelConstants.sheetsChannel,
        binaryMessenger: messenger
      )
      channel.invokeMethod(
        NativeChannelConstants.SheetMethod.nativeEntryFormSubmitted,
        arguments: payload.dictionary
      ) { [weak self] result in
        let didSave = (result as? Bool) == true
        DispatchQueue.main.async {
          completion(didSave)
          if didSave {
            self?.reset()
          }
        }
      }
      },
      onDismiss: { [weak self] in
        self?.reset()
      }
    )
    let navigationController = UINavigationController(rootViewController: formViewController)
    navigationController.modalPresentationStyle = .pageSheet
    navigationController.view.backgroundColor = .clear
    navigationController.navigationBar.isTranslucent = true
    navigationController.navigationBar.backgroundColor = .clear
    navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationController.navigationBar.shadowImage = UIImage()
    if #available(iOS 15.0, *) {
      if let sheet = navigationController.sheetPresentationController {
        if #available(iOS 16.0, *) {
          let compactDetentIdentifier = UISheetPresentationController.Detent.Identifier("nativeEntryFormCompact")
          sheet.detents = [
            .custom(identifier: compactDetentIdentifier) { context in
              context.maximumDetentValue * 0.8
            },
            .large(),
          ]
          sheet.selectedDetentIdentifier = compactDetentIdentifier
        } else {
          sheet.detents = [.medium(), .large()]
          sheet.selectedDetentIdentifier = .medium
        }
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 24
      }
    }
    formViewController.onKeyboardVisibilityChanged = { [weak navigationController] isVisible in
      if #available(iOS 15.0, *) {
        guard let sheet = navigationController?.sheetPresentationController else { return }
        sheet.animateChanges {
          if isVisible {
            sheet.selectedDetentIdentifier = .large
          } else if #available(iOS 16.0, *) {
            sheet.selectedDetentIdentifier = UISheetPresentationController.Detent.Identifier("nativeEntryFormCompact")
          } else {
            sheet.selectedDetentIdentifier = .medium
          }
        }
      }
    }
    let presentationDelegate = PresentationDelegate { [weak self] in
      self?.reset()
    }
    self.presentationDelegate = presentationDelegate
    navigationController.presentationController?.delegate = presentationDelegate
    presentedNavigationController = navigationController
    presenter.present(navigationController, animated: true) { [weak self, weak navigationController] in
      guard let self, let navigationController, navigationController.presentingViewController != nil else {
        self?.reset()
        return
      }
    }
    return true
  }

  private func reset() {
    isPresented = false
    presentedNavigationController = nil
    presentationDelegate = nil
  }
}

private final class PresentationDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
  private let onDismiss: () -> Void

  init(onDismiss: @escaping () -> Void) {
    self.onDismiss = onDismiss
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    onDismiss()
  }
}
