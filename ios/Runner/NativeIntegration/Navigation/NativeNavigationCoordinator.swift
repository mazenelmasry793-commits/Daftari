import Flutter
import UIKit

final class NativeNavigationCoordinator {
  private let rootViewController: FlutterViewController
  private let sheetCoordinator: NativeSheetCoordinator
  private var channel: FlutterMethodChannel?
  private var navigationView: NativeFloatingNavigationView?
  private var settingsButton: NativeSettingsButtonView?
  private var navigationVisible = false
  private var searchModeActive = false
  // Keeps the native control clear of the screen edge while preserving its
  // safe-area-aligned header position.
  private let settingsButtonTrailingInset: CGFloat = 8

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
    let settingsButton = NativeSettingsButtonView()
    let navigationView = NativeFloatingNavigationView(
      onTabSelected: { [weak channel] index in
        channel?.invokeMethod(
          NativeChannelConstants.NavigationMethod.nativeTabSelected,
          arguments: ["index": index]
        )
      },
      onAddEntryTypeSelected: { [weak self] type in
        _ = self?.sheetCoordinator.presentNativeEntryForm(type: type)
      },
      onSearchQueryChanged: { [weak channel] query in
        channel?.invokeMethod("nativeSearchQueryChanged", arguments: query)
      },
      onSearchDismissed: { [weak channel] in
        channel?.invokeMethod("nativeSearchDismissed", arguments: nil)
      },
      onSearchModeChanged: { [weak self] active in
        self?.searchModeActive = active
        self?.updateSettingsVisibility(animated: true)
      }
    )
    settingsButton.onSettingsRequested = { [weak channel] in
      channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
    }
    rootViewController.view.addSubview(navigationView)
    navigationView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      navigationView.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
      navigationView.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
      navigationView.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      navigationView.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
    ])

    rootViewController.view.addSubview(settingsButton)
    NSLayoutConstraint.activate([
      settingsButton.trailingAnchor.constraint(
        equalTo: rootViewController.view.trailingAnchor,
        constant: -settingsButtonTrailingInset
      ),
      settingsButton.centerYAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.topAnchor, constant: 28),
      settingsButton.widthAnchor.constraint(equalToConstant: 48),
      settingsButton.heightAnchor.constraint(equalToConstant: 48),
    ])

    channel.setMethodCallHandler { [weak self, weak navigationView, weak settingsButton] call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case NativeChannelConstants.NavigationMethod.setSelectedTab:
        navigationView?.setSelectedTab(arguments?["index"] as? Int ?? 0)
        result(nil)
      case NativeChannelConstants.NavigationMethod.setNavigationVisible:
        let visible = arguments?["visible"] as? Bool ?? false
        self?.navigationVisible = visible
        navigationView?.setNavigationVisible(visible)
        self?.updateSettingsVisibility(animated: true)
        result(nil)
      case "setSearchVisible":
        navigationView?.setSearchVisible(arguments?["visible"] as? Bool ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.channel = channel
    self.navigationView = navigationView
    self.settingsButton = settingsButton
  }

  private func updateSettingsVisibility(animated: Bool) {
    settingsButton?.setVisible(navigationVisible && !searchModeActive, animated: animated)
  }

  deinit {
    channel?.setMethodCallHandler(nil)
  }
}
