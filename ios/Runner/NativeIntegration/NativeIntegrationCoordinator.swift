import Flutter
import UIKit

final class NativeIntegrationCoordinator {
  private let rootViewController: FlutterViewController
  private let navigationCoordinator: NativeNavigationCoordinator
  private let sheetCoordinator: NativeSheetCoordinator

  init(rootViewController: FlutterViewController) {
    self.rootViewController = rootViewController
    self.sheetCoordinator = NativeSheetCoordinator()
    self.navigationCoordinator = NativeNavigationCoordinator(
      rootViewController: rootViewController,
      sheetCoordinator: sheetCoordinator
    )
  }

  func start() {
    sheetCoordinator.configure(messenger: rootViewController.binaryMessenger)
    navigationCoordinator.start()
  }
}
