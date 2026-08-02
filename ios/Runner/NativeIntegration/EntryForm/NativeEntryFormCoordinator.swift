import Flutter
import SwiftUI
import UIKit

final class NativeEntryFormCoordinator {
  // Shared compact height keeps the two debt forms aligned.
  private static let compactEntryFormHeight: CGFloat = 510

  private weak var presentedNavigationController: UINavigationController?
  private weak var presentedViewController: UIViewController?
  private var presentationDelegate: PresentationDelegate?
  private var isPresented = false

  func present(
    type: String,
    initialValues: NativeEntryFormInitialValues? = nil,
    from presenter: UIViewController,
    messenger: FlutterBinaryMessenger,
    onDismiss: (() -> Void)? = nil
  ) -> Bool {
    recoverStalePresentationIfNeeded()
    guard !isPresented,
          let entryType = NativeEntryFormType(rawValue: type),
          presenter.viewIfLoaded?.window != nil,
          !presenter.isBeingDismissed,
          !presenter.isBeingPresented else {
      reset()
      return false
    }
    isPresented = true

    if #available(iOS 16.4, *) {
      return presentDebtForm(
        entryType: entryType,
        initialValues: initialValues,
        from: presenter,
        messenger: messenger,
        onDismiss: onDismiss
      )
    }

    let formViewController = NativeEntryFormViewController(
      entryType: entryType,
      initialValues: initialValues,
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
              min(Self.compactEntryFormHeight, context.maximumDetentValue)
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
        onDismiss?()
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

  @available(iOS 16.4, *)
  private func presentDebtForm(
    entryType: NativeEntryFormType,
    initialValues: NativeEntryFormInitialValues?,
    from presenter: UIViewController,
    messenger: FlutterBinaryMessenger,
    onDismiss: (() -> Void)?
  ) -> Bool {
    let formViewController = UIHostingController(
      rootView: NativeDebtFormView(
        entryType: entryType,
        initialValues: initialValues,
        onSubmit: { [weak self] payload, completion in
          let channel = FlutterMethodChannel(
            name: NativeChannelConstants.sheetsChannel,
            binaryMessenger: messenger
          )
          channel.invokeMethod(
            NativeChannelConstants.SheetMethod.nativeEntryFormSubmitted,
            arguments: payload.dictionary
          ) { result in
            let didSave = (result as? Bool) == true
            DispatchQueue.main.async {
              completion(didSave)
              if didSave { self?.reset() }
            }
          }
        }
      )
    )
    formViewController.modalPresentationStyle = .pageSheet
    formViewController.view.backgroundColor = .clear
    if #available(iOS 15.0, *), let sheet = formViewController.sheetPresentationController {
      if #available(iOS 16.0, *) {
        sheet.detents = [
          .custom(identifier: .init("nativeDebtFormCompact")) { context in
            min(Self.compactEntryFormHeight, context.maximumDetentValue)
          },
        ]
      } else {
        sheet.detents = [.medium()]
      }
      sheet.selectedDetentIdentifier = sheet.detents.first?.identifier
      sheet.prefersGrabberVisible = true
      sheet.preferredCornerRadius = 28
    }
    let presentationDelegate = PresentationDelegate { [weak self] in
      self?.reset()
      onDismiss?()
    }
    self.presentationDelegate = presentationDelegate
    formViewController.presentationController?.delegate = presentationDelegate
    presentedViewController = formViewController
    presenter.present(formViewController, animated: true) { [weak self, weak formViewController] in
      guard let self, let formViewController, formViewController.presentingViewController != nil else {
        self?.reset()
        return
      }
    }
    return true
  }

  private func reset() {
    isPresented = false
    presentedNavigationController = nil
    presentedViewController = nil
    presentationDelegate = nil
  }

  private func recoverStalePresentationIfNeeded() {
    guard isPresented else { return }
    guard let presentedViewController,
          presentedViewController.presentingViewController != nil,
          presentedViewController.viewIfLoaded?.window != nil,
          !presentedViewController.isBeingDismissed else {
      reset()
      return
    }
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
