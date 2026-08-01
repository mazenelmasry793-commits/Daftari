import Flutter
import UIKit

final class NativeNavigationCoordinator {
  private let rootViewController: FlutterViewController
  private let sheetCoordinator: NativeSheetCoordinator
  private var channel: FlutterMethodChannel?
  private var navigationView: NativeFloatingNavigationView?

  init(rootViewController: FlutterViewController, sheetCoordinator: NativeSheetCoordinator) {
    self.rootViewController = rootViewController
    self.sheetCoordinator = sheetCoordinator
    self.sheetCoordinator.onRequestAddEntryMenu = { [weak self] in
      self?.navigationView?.presentAddMenu()
    }
  }

  func start() {
    guard navigationView == nil else { return }

    let channel = FlutterMethodChannel(
      name: NativeChannelConstants.navigationChannel,
      binaryMessenger: rootViewController.binaryMessenger
    )
    let navigationView = NativeFloatingNavigationView(
      onTabSelected: { [weak channel] index in
        channel?.invokeMethod(
          NativeChannelConstants.NavigationMethod.nativeTabSelected,
          arguments: ["index": index]
        )
      },
      onAddEntryTypeSelected: { [weak self] type in
        _ = self?.sheetCoordinator.presentNativeEntryForm(type: type)
      }
    )

    rootViewController.view.addSubview(navigationView)
    navigationView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      navigationView.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
      navigationView.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
      navigationView.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      navigationView.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
    ])

    channel.setMethodCallHandler { [weak navigationView] call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case NativeChannelConstants.NavigationMethod.setSelectedTab:
        navigationView?.setSelectedTab(arguments?["index"] as? Int ?? 0)
        result(nil)
      case NativeChannelConstants.NavigationMethod.setNavigationVisible:
        navigationView?.setNavigationVisible(arguments?["visible"] as? Bool ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.channel = channel
    self.navigationView = navigationView
  }

  deinit {
    channel?.setMethodCallHandler(nil)
  }
}
