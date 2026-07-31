import Flutter
import UIKit

final class NativeSheetCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
  static let shared = NativeSheetCoordinator()

  private(set) var isPresented = false
  private var sheetsChannel: FlutterMethodChannel?
  private weak var currentPresenter: UIViewController?

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.daftari/native_sheets", binaryMessenger: messenger)
    self.sheetsChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "showAddEntryChooser":
        if let presenter = self?.findTopViewController() {
          self?.presentAddEntryChooser(from: presenter)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func presentAddEntryChooser(from presenter: UIViewController) {
    guard !isPresented else { return }
    isPresented = true
    currentPresenter = presenter

    let sheetVC = NativeAddEntrySheetViewController { [weak self] selectedOption in
      self?.dismissAndNotify(selectedOption: selectedOption)
    }

    sheetVC.modalPresentationStyle = .pageSheet
    if let sheet = sheetVC.sheetPresentationController {
      sheet.prefersGrabberVisible = true
      sheet.preferredCornerRadius = 24
      if #available(iOS 16.0, *) {
        sheet.detents = [
          .custom(identifier: .init("addEntryChooser")) { context in
            min(350, context.maximumDetentValue)
          }
        ]
      } else {
        sheet.detents = [.medium()]
      }
    }

    sheetVC.presentationController?.delegate = self
    presenter.present(sheetVC, animated: true)
  }

  private func dismissAndNotify(selectedOption: NativeAddEntryOption) {
    guard let presenter = currentPresenter ?? findTopViewController() else { return }
    presenter.dismiss(animated: true) { [weak self] in
      self?.isPresented = false
      self?.sheetsChannel?.invokeMethod("addEntryTypeSelected", arguments: ["type": selectedOption.rawValue])
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    isPresented = false
    sheetsChannel?.invokeMethod("addEntryChooserDismissed", arguments: nil)
  }

  private func findTopViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      return nil
    }
    var top = rootVC
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}
