import Flutter
import UIKit

final class NativeSheetCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
  private enum PresentationKind {
    case datePicker(completion: (Date?) -> Void)
  }

  private var sheetsChannel: FlutterMethodChannel?
  private var binaryMessenger: FlutterBinaryMessenger?
  private let entryFormCoordinator = NativeEntryFormCoordinator()
  private var presentationKind: PresentationKind?
  private weak var currentPresenter: UIViewController?
  var onRequestAddEntryMenu: (() -> Void)?

  var isPresented: Bool { presentationKind != nil }

  func configure(messenger: FlutterBinaryMessenger) {
    binaryMessenger = messenger
    let channel = FlutterMethodChannel(
      name: NativeChannelConstants.sheetsChannel,
      binaryMessenger: messenger
    )
    sheetsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case NativeChannelConstants.SheetMethod.showAddEntryChooser:
      onRequestAddEntryMenu?()
      result(nil)
    case NativeChannelConstants.SheetMethod.showNativeDatePicker:
      let arguments = call.arguments as? [String: Any]
      let initialDate = parseDate(arguments?["initialDate"] as? String) ?? Date()
      let minimumDate = parseDate(arguments?["minimumDate"] as? String)
      let maximumDate = parseDate(arguments?["maximumDate"] as? String)
      guard let presenter = topViewController(), presentationKind == nil else {
        result(nil)
        return
      }
      let picker = NativeDatePickerViewController(
        initialDate: initialDate,
        minimumDate: minimumDate,
        maximumDate: maximumDate
      ) { [weak self] selectedDate in
        self?.completeDatePicker(selectedDate: selectedDate)
      }
      presentationKind = .datePicker { [weak self] selectedDate in
        result(selectedDate.map { self?.formatDate($0) ?? "" })
      }
      currentPresenter = presenter
      configureSheet(picker, detentHeight: 440, identifier: "nativeDatePicker")
      picker.presentationController?.delegate = self
      presenter.present(picker, animated: true) { [weak self, weak picker] in
        guard let self, let picker, picker.presentingViewController != nil else {
          self?.completeDatePicker(selectedDate: nil)
          return
        }
      }
    case NativeChannelConstants.SheetMethod.showNativeEntryForm:
      let arguments = call.arguments as? [String: Any]
      if let type = arguments?["type"] as? String { _ = presentNativeEntryForm(type: type) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @discardableResult
  func presentNativeEntryForm(type: String) -> Bool {
    guard let presenter = topViewController(),
          let binaryMessenger else { return false }
    return entryFormCoordinator.present(type: type, from: presenter, messenger: binaryMessenger)
  }

  @discardableResult
  func presentNativeEntryEdit(
    snapshot: NativeEntryDetailsSnapshot,
    onSaveSucceeded: @escaping () -> Void,
    onDismiss: @escaping () -> Void
  ) -> Bool {
    guard let presenter = topViewController(),
          let binaryMessenger,
          let type = NativeEntryFormType(rawValue: snapshot.type),
          let id = Int(snapshot.id) else { return false }
    let initialValues = NativeEntryFormInitialValues(
      id: id,
      type: type,
      title: snapshot.title,
      amount: snapshot.originalAmount,
      paidAmount: snapshot.paidAmount,
      note: snapshot.note,
      debtDate: snapshot.date ?? Date()
    )
    return entryFormCoordinator.present(
      type: type.rawValue,
      initialValues: initialValues,
      from: presenter,
      messenger: binaryMessenger,
      onSaveSucceeded: onSaveSucceeded,
      onDismiss: onDismiss
    )
  }

  private func completeDatePicker(selectedDate: Date?) {
    guard case .datePicker(let completion) = presentationKind else { return }
    resetPresentation()
    completion(selectedDate)
  }

  private func configureSheet(_ viewController: UIViewController, detentHeight: CGFloat, identifier: String) {
    viewController.modalPresentationStyle = .pageSheet
    if #available(iOS 15.0, *) {
      if let sheet = viewController.sheetPresentationController {
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 24
        if #available(iOS 16.0, *) {
          sheet.detents = [.custom(identifier: .init(identifier)) { context in
            min(detentHeight, context.maximumDetentValue)
          }]
        } else {
          sheet.detents = [.medium()]
        }
      }
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    switch presentationKind {
    case .datePicker(let completion):
      resetPresentation()
      completion(nil)
    case nil:
      break
    }
  }

  private func resetPresentation() {
    presentationKind = nil
    currentPresenter = nil
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractionalFormatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  private func formatDate(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .sorted { lhs, rhs in
        let lhsActive = lhs.activationState == .foregroundActive
        let rhsActive = rhs.activationState == .foregroundActive
        return lhsActive && !rhsActive
      }
    guard let window = scenes
      .flatMap(\.windows)
      .first(where: { $0.isKeyWindow && !$0.isHidden }),
      let root = window.rootViewController else {
      return nil
    }
    let top = topViewController(from: root)
    guard top.viewIfLoaded?.window != nil,
          !top.isBeingDismissed,
          !top.isBeingPresented else { return nil }
    return top
  }

  private func topViewController(from viewController: UIViewController) -> UIViewController {
    if let presented = viewController.presentedViewController,
       !presented.isBeingDismissed {
      return topViewController(from: presented)
    }
    if let navigationController = viewController as? UINavigationController,
       let visible = navigationController.visibleViewController {
      return topViewController(from: visible)
    }
    if let tabBarController = viewController as? UITabBarController,
       let selected = tabBarController.selectedViewController {
      return topViewController(from: selected)
    }
    return viewController
  }
}
