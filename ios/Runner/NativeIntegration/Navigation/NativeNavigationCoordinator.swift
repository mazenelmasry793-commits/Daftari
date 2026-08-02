import Flutter
import UIKit

final class NativeNavigationCoordinator {
  private let rootViewController: FlutterViewController
  private let sheetCoordinator: NativeSheetCoordinator
  private var channel: FlutterMethodChannel?
  private var navigationView: NativeFloatingNavigationView?
  private var systemTabBarController: AnyObject?
  private var navigationBarHost: AnyObject?
  private var dashboardBridge: AnyObject?
  private var nativeDashboardHost: UIViewController?
  private var entriesBridge: NativeEntriesBridge?
  private var nativeEntryHosts: [NativeEntryListType: UIViewController] = [:]
  private var nativeEntryDetailsBridge: NativeEntryDetailsBridge?
  private var nativeEntryDetailsHost: UIViewController?
  private var settingsButton: NativeSettingsButtonView?
  private var selectedTabIndex = 0
  private var searchModeActive = false
  private var navigationVisible = true
  private var flutterDetailVisible = false
  private var nativeDetailVisible = false
  private var nativeDashboardInstalled = false
  // Keeps the native control clear of the screen edge while preserving its
  // safe-area-aligned header position.
  private let settingsButtonTrailingInset: CGFloat = 8

  init(rootViewController: FlutterViewController, sheetCoordinator: NativeSheetCoordinator) {
    self.rootViewController = rootViewController
    self.sheetCoordinator = sheetCoordinator
    self.sheetCoordinator.onRequestAddEntryMenu = { [weak self] in
      self?.navigationView?.presentAddMenu()
      if #available(iOS 26.0, *) {
        (self?.navigationBarHost as? DaftariNavigationBarHostViewController)?.presentAddMenu()
      }
    }
  }

  func start() {
    guard navigationView == nil else { return }

    let channel = FlutterMethodChannel(
      name: NativeChannelConstants.navigationChannel,
      binaryMessenger: rootViewController.binaryMessenger
    )
    var settingsButton: NativeSettingsButtonView?
    if #unavailable(iOS 26.0) {
      settingsButton = NativeSettingsButtonView()
    }
    if #available(iOS 26.0, *) {
      let dashboardBridge = NativeDashboardBridge(binaryMessenger: rootViewController.binaryMessenger)
      let dashboardHost = NativeDashboardHostController(
        dashboardBridge: dashboardBridge,
        onAddEntryTypeSelected: { [weak self] type in
          _ = self?.sheetCoordinator.presentNativeEntryForm(type: type)
        },
        onSettingsRequested: { [weak channel] in
          channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
        },
        onEntrySelected: { [weak self] id, type in
          guard let self else { return }
          if type == NativeEntryListType.scratchpad.rawValue {
            (self.dashboardBridge as? NativeDashboardBridge)?.openEntryDetails(id: id)
          } else {
            self.openNativeDetails(id: id)
          }
        }
      )
      self.dashboardBridge = dashboardBridge
      self.nativeDashboardHost = dashboardHost
      rootViewController.addChild(dashboardHost)
      rootViewController.view.addSubview(dashboardHost.view)
      dashboardHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        dashboardHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        dashboardHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        dashboardHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        dashboardHost.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      dashboardHost.didMove(toParent: rootViewController)
      nativeDashboardInstalled = true
      let entriesBridge = NativeEntriesBridge(binaryMessenger: rootViewController.binaryMessenger)
      self.entriesBridge = entriesBridge
      for type in [NativeEntryListType.owedToMe, .owedByMe, .scratchpad] {
        let host = NativeEntriesHostController(
          store: entriesBridge.store,
          type: type,
          onAdd: { [weak self] in
            _ = self?.sheetCoordinator.presentNativeEntryForm(type: type.rawValue)
          },
          onSettings: { [weak channel] in
            channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
          },
          onEntrySelected: { [weak self] id in
            guard let self else { return }
            if type == .scratchpad {
              entriesBridge.openEntryDetails(id: id)
            } else {
              self.openNativeDetails(id: id)
            }
          }
        )
        rootViewController.addChild(host)
        rootViewController.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
          host.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
          host.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
          host.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
          host.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
        ])
        host.didMove(toParent: rootViewController)
        nativeEntryHosts[type] = host
      }
    }
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
        self?.updateNativeSurfaceVisibility(animated: true)
      }
    )
    settingsButton?.onSettingsRequested = { [weak channel] in
      channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
    }
    if #available(iOS 26.0, *) {
      let systemTabs = DaftariSystemTabBarController(
        onTabSelected: { [weak self, weak channel] index in
          self?.selectedTabIndex = index
          self?.searchModeActive = false
          self?.updateNativeSurfaceVisibility(animated: true)
          channel?.invokeMethod(
            NativeChannelConstants.NavigationMethod.nativeTabSelected,
            arguments: ["index": index]
          )
        },
        onSearchActivated: { [weak self, weak channel] in
          self?.selectedTabIndex = 4
          self?.searchModeActive = true
          self?.updateNativeSurfaceVisibility(animated: true)
          channel?.invokeMethod("nativeSearchActivated", arguments: nil)
        },
        onSearchQueryChanged: { [weak channel] query in
          channel?.invokeMethod("nativeSearchQueryChanged", arguments: query)
        },
        onSearchDismissed: { [weak channel] in
          channel?.invokeMethod("nativeSearchDismissed", arguments: nil)
        },
        onSearchModeChanged: { [weak self] active in
          self?.searchModeActive = active
          self?.updateNativeSurfaceVisibility(animated: true)
        }
      )
      rootViewController.addChild(systemTabs.viewController)
      rootViewController.view.addSubview(systemTabs.viewController.view)
      systemTabs.viewController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        systemTabs.viewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        systemTabs.viewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        systemTabs.viewController.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        systemTabs.viewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      systemTabs.viewController.didMove(toParent: rootViewController)
      self.systemTabBarController = systemTabs
      let navigationBarHost = DaftariNavigationBarHostViewController(
        onSettingsRequested: { [weak channel] in
          channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
        },
        onAddEntryTypeSelected: { [weak self] type in
          _ = self?.sheetCoordinator.presentNativeEntryForm(type: type)
        }
      )
      rootViewController.addChild(navigationBarHost)
      rootViewController.view.addSubview(navigationBarHost.view)
      navigationBarHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        navigationBarHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        navigationBarHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        navigationBarHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        navigationBarHost.view.heightAnchor.constraint(equalToConstant: 96),
      ])
      navigationBarHost.didMove(toParent: rootViewController)
      self.navigationBarHost = navigationBarHost

      let entryDetailsBridge = NativeEntryDetailsBridge(
        binaryMessenger: rootViewController.binaryMessenger
      )
      entryDetailsBridge.onActionFinished = { [weak self] id, close in
        self?.finishNativeDetailsAction(id: id, close: close)
      }
      let entryDetailsHost = NativeEntryDetailsHostController(
        bridge: entryDetailsBridge,
        onBack: { [weak self] in self?.closeNativeDetails() },
        onEdit: { [weak self] snapshot in self?.openNativeEdit(snapshot: snapshot) }
      )
      rootViewController.addChild(entryDetailsHost)
      rootViewController.view.addSubview(entryDetailsHost.view)
      entryDetailsHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        entryDetailsHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        entryDetailsHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        entryDetailsHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        entryDetailsHost.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      entryDetailsHost.didMove(toParent: rootViewController)
      entryDetailsHost.view.isHidden = true
      self.nativeEntryDetailsBridge = entryDetailsBridge
      self.nativeEntryDetailsHost = entryDetailsHost
      updateNativeSurfaceVisibility(animated: false)
    } else {
      rootViewController.view.addSubview(navigationView)
      navigationView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        navigationView.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        navigationView.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        navigationView.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
        navigationView.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
      ])
    }

    if let settingsButton {
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
    }

    channel.setMethodCallHandler { [weak self, weak navigationView, weak settingsButton] call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case NativeChannelConstants.NavigationMethod.setSelectedTab:
        navigationView?.setSelectedTab(arguments?["index"] as? Int ?? 0)
        if #available(iOS 26.0, *) {
          if let index = arguments?["index"] as? Int {
            self?.selectedTabIndex = index
            (self?.systemTabBarController as? DaftariSystemTabBarController)?.setSelectedTab(index)
            self?.updateNativeSurfaceVisibility(animated: false)
          }
        }
        result(nil)
      case NativeChannelConstants.NavigationMethod.setNavigationVisible:
        let visible = arguments?["visible"] as? Bool ?? false
        self?.navigationVisible = visible
        navigationView?.setNavigationVisible(visible)
        if #available(iOS 26.0, *) {
          (self?.systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(visible, animated: true)
        }
        self?.updateNativeSurfaceVisibility(animated: true)
        result(nil)
      case "setSearchVisible":
        navigationView?.setSearchVisible(arguments?["visible"] as? Bool ?? false)
        if #available(iOS 26.0, *) {
          if arguments?["visible"] as? Bool == true {
            (self?.systemTabBarController as? DaftariSystemTabBarController)?.activateSearchTab()
          }
        }
        result(nil)
      case "activateSearchTab":
        if #available(iOS 26.0, *) {
          (self?.systemTabBarController as? DaftariSystemTabBarController)?.activateSearchTab()
        } else {
          navigationView?.setSearchVisible(true)
        }
        result(nil)
      case "setFlutterDetailVisible":
        let visible = arguments?["visible"] as? Bool ?? true
        self?.flutterDetailVisible = visible
        self?.updateNativeSurfaceVisibility(animated: false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.channel = channel
    self.navigationView = navigationView
    self.settingsButton = settingsButton
    // Establish the initial native surface immediately. Flutter still owns
    // subsequent visibility changes through the existing navigation channel.
    if #available(iOS 26.0, *) {
      navigationVisible = true
      (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(true, animated: false)
      if let systemTabs = systemTabBarController as? DaftariSystemTabBarController {
        rootViewController.view.bringSubviewToFront(systemTabs.viewController.view)
        if let navigationBarHost = navigationBarHost as? DaftariNavigationBarHostViewController {
          rootViewController.view.bringSubviewToFront(navigationBarHost.view)
        }
      }
      updateNativeSurfaceVisibility(animated: false)
    }
  }

  private func updateNativeSurfaceVisibility(animated: Bool) {
    if #available(iOS 26.0, *) {
      let homeSelected = selectedTabIndex == 0
      let shouldShowNativeDashboard =
        nativeDashboardInstalled &&
        navigationVisible &&
        homeSelected &&
        !searchModeActive &&
        !flutterDetailVisible &&
        !nativeDetailVisible
      let shouldShowLegacyHeader =
        false

      nativeDashboardHost?.view.isHidden = !shouldShowNativeDashboard
      for (type, host) in nativeEntryHosts {
        let tabIndex: Int
        switch type {
        case .owedToMe: tabIndex = 1
        case .owedByMe: tabIndex = 2
        case .scratchpad: tabIndex = 3
        }
        host.view.isHidden = !(
          nativeDashboardInstalled &&
          navigationVisible &&
          selectedTabIndex == tabIndex &&
          !searchModeActive &&
          !flutterDetailVisible &&
          !nativeDetailVisible
        )
      }
      nativeEntryDetailsHost?.view.isHidden = !nativeDetailVisible
      (navigationBarHost as? DaftariNavigationBarHostViewController)?.setVisible(
        shouldShowLegacyHeader,
        animated: animated
      )

      #if DEBUG
      NSLog(
        "Daftari native surfaces tab=%d search=%@ navigation=%@ detail=%@ dashboard=%@ header=%@ tabBarHidden=%@",
        selectedTabIndex,
        String(searchModeActive),
        String(navigationVisible),
        String(flutterDetailVisible),
        String(shouldShowNativeDashboard),
        String(shouldShowLegacyHeader),
        String((systemTabBarController as? DaftariSystemTabBarController)?.viewController.isTabBarHidden ?? false)
      )
      #endif
    } else {
      settingsButton?.setVisible(
        navigationVisible && !searchModeActive,
        animated: animated
      )
    }
  }

  @available(iOS 26.0, *)
  private func openNativeDetails(id: String) {
    guard !nativeDetailVisible, !flutterDetailVisible,
          let detailsHost = nativeEntryDetailsHost,
          let detailsBridge = nativeEntryDetailsBridge else { return }
    nativeDetailVisible = true
    navigationVisible = false
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(false, animated: true)
    detailsHost.view.isHidden = false
    rootViewController.view.bringSubviewToFront(detailsHost.view)
    detailsBridge.load(id: id)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func closeNativeDetails() {
    guard nativeDetailVisible else { return }
    nativeDetailVisible = false
    navigationVisible = true
    nativeEntryDetailsHost?.view.isHidden = true
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(true, animated: true)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func finishNativeDetailsAction(id: String, close: Bool) {
    guard !close else {
      navigationVisible = true
      return
    }
    guard !flutterDetailVisible,
          let detailsBridge = nativeEntryDetailsBridge,
          let detailsHost = nativeEntryDetailsHost else { return }
    nativeDetailVisible = true
    detailsBridge.load(id: id)
    detailsHost.view.isHidden = false
    rootViewController.view.bringSubviewToFront(detailsHost.view)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func openNativeEdit(snapshot: NativeEntryDetailsSnapshot) {
    guard nativeDetailVisible else { return }
    let presented = sheetCoordinator.presentNativeEntryEdit(snapshot: snapshot) { [weak self] in
      self?.finishNativeDetailsAction(id: snapshot.id, close: false)
    }
    if !presented {
      finishNativeDetailsAction(id: snapshot.id, close: false)
    }
  }

  deinit {
    channel?.setMethodCallHandler(nil)
  }
}
