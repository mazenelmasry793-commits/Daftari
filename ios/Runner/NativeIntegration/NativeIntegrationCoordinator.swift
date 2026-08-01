import Flutter
import UIKit

final class NativeIntegrationCoordinator {
  private let rootViewController: FlutterViewController
  private let navigationCoordinator: NativeNavigationCoordinator
  private let sheetCoordinator: NativeSheetCoordinator
  private let toastCoordinator: NativeToastCoordinator

  init(rootViewController: FlutterViewController) {
    self.rootViewController = rootViewController
    self.sheetCoordinator = NativeSheetCoordinator()
    self.navigationCoordinator = NativeNavigationCoordinator(
      rootViewController: rootViewController,
      sheetCoordinator: sheetCoordinator
    )
    self.toastCoordinator = NativeToastCoordinator(rootView: rootViewController.view)
  }

  func start() {
    sheetCoordinator.configure(messenger: rootViewController.binaryMessenger)
    toastCoordinator.configure(messenger: rootViewController.binaryMessenger)
    navigationCoordinator.start()
  }
}
