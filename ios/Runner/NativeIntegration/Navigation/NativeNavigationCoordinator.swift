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
  private var nativeNoteDetailsBridge: NativeNoteDetailsBridge?
  private var nativeNoteDetailsHost: UIViewController?
  private var nativeSettingsHost: UIViewController?
  private var nativeTrashHost: UIViewController?
  private var settingsButton: NativeSettingsButtonView?
  private var selectedTabIndex = 0
  private enum SearchLifecycleState {
    case inactive
    case presenting
    case active
    case dismissing
  }
  private var searchState: SearchLifecycleState = .inactive
  private var lastContentTabIndex = 0
  private var searchModeActive: Bool { searchState != .inactive }
  private var navigationVisible = true
  private var flutterDetailVisible = false
  private var nativeDetailVisible = false
  private var nativeNoteDetailVisible = false
  private var nativeSettingsVisible = false
  private var nativeTrashVisible = false
  private var trashActionInFlight = false
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
        onSettingsRequested: { [weak self] in
          self?.openNativeSettings()
        },
        onEntrySelected: { [weak self] id, type in
          guard let self else { return }
          if type == NativeEntryListType.scratchpad.rawValue {
            self.openNativeNoteDetails(id: id)
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
          onSettings: { [weak self] in
            self?.openNativeSettings()
          },
          onEntrySelected: { [weak self] id in
            guard let self else { return }
            if type == .scratchpad {
              self.openNativeNoteDetails(id: id)
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
        self?.updateLegacySearchMode(active)
      }
    )
    settingsButton?.onSettingsRequested = { [weak channel] in
      channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
    }
    if #available(iOS 26.0, *) {
      let systemTabs = DaftariSystemTabBarController(
        onTabSelected: { [weak self, weak channel] index in
          self?.handleNativeTabSelection(index, channel: channel)
        },
        onSearchActivated: { [weak self, weak channel] in
          self?.beginNativeSearchActivation(channel: channel)
        },
        onSearchQueryChanged: { [weak channel] query in
          channel?.invokeMethod("nativeSearchQueryChanged", arguments: query)
        },
        onSearchDismissed: { [weak self, weak channel] in
          self?.finishNativeSearchDismissal(channel: channel)
        },
        onSearchModeChanged: { [weak self] active in
          self?.applyNativeSearchModeChange(active)
        },
        onSearchResultSelected: { [weak self] id, type in
          guard let self else { return }
          self.searchState = .inactive
          if type == "scratchpad" {
            self.openNativeNoteDetails(id: id)
          } else {
            self.openNativeDetails(id: id)
          }
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
      setHost(entryDetailsHost, visible: false)
      self.nativeEntryDetailsBridge = entryDetailsBridge
      self.nativeEntryDetailsHost = entryDetailsHost

      let noteDetailsBridge = NativeNoteDetailsBridge(
        binaryMessenger: rootViewController.binaryMessenger
      )
      let noteDetailsHost = NativeNoteDetailsHostController(
        bridge: noteDetailsBridge,
        onBack: { [weak self] in self?.closeNativeNoteDetails() }
      )
      rootViewController.addChild(noteDetailsHost)
      rootViewController.view.addSubview(noteDetailsHost.view)
      noteDetailsHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        noteDetailsHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        noteDetailsHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        noteDetailsHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        noteDetailsHost.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      noteDetailsHost.didMove(toParent: rootViewController)
      setHost(noteDetailsHost, visible: false)
      self.nativeNoteDetailsBridge = noteDetailsBridge
      self.nativeNoteDetailsHost = noteDetailsHost

      let settingsHost = NativeSettingsHostController(
        onBack: { [weak self] in self?.closeNativeSettings() },
        onTrash: { [weak self] in self?.openNativeTrash() },
        onExport: { [weak self] in self?.requestSettingsExport() },
        onImportData: { [weak self] contents in self?.requestSettingsImportPreview(contents: contents) },
        onEmptyTrash: { [weak self] in self?.requestSettingsMutation(method: "nativeSettingsEmptyTrash") },
        onDeleteAllData: { [weak self] in self?.requestSettingsMutation(method: "nativeSettingsDeleteAllData") }
      )
      rootViewController.addChild(settingsHost)
      rootViewController.view.addSubview(settingsHost.view)
      settingsHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        settingsHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        settingsHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        settingsHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        settingsHost.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      settingsHost.didMove(toParent: rootViewController)
      setHost(settingsHost, visible: false)
      self.nativeSettingsHost = settingsHost

      let trashHost = NativeTrashHostController(
        onBack: { [weak self] in self?.closeNativeTrash() },
        onEntrySelected: { [weak self] id in
          guard let self else { return }
          self.nativeTrashVisible = false
          self.openNativeDetails(id: id)
        },
        onRestore: { [weak self] id in
          self?.requestTrashAction(method: "nativeTrashRestore", id: id)
        },
        onDeleteForeverConfirmed: { [weak self] id in
          self?.requestTrashAction(method: "nativeTrashDeleteForever", id: id)
        },
        onEmptyTrashConfirmed: { [weak self] in
          self?.requestTrashAction(method: "nativeTrashEmpty", id: nil)
        }
      )
      rootViewController.addChild(trashHost)
      rootViewController.view.addSubview(trashHost.view)
      trashHost.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        trashHost.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        trashHost.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        trashHost.view.topAnchor.constraint(equalTo: rootViewController.view.topAnchor),
        trashHost.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      trashHost.didMove(toParent: rootViewController)
      setHost(trashHost, visible: false)
      self.nativeTrashHost = trashHost
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
            guard (0...3).contains(index) else {
              result(nil)
              return
            }
            if index == self?.selectedTabIndex && self?.searchState == .inactive {
              result(nil)
              return
            }
            self?.selectedTabIndex = index
            if (0...3).contains(index) {
              self?.lastContentTabIndex = index
            }
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
      case "nativeSettingsRestored":
        if #available(iOS 26.0, *) { self?.restoreNativeSettings() }
        result(nil)
      case "restoreNativeSettings":
        if #available(iOS 26.0, *) { self?.restoreNativeSettings() }
        result(nil)
      case "nativeTrashSnapshotUpdated":
        if #available(iOS 26.0, *) {
          (self?.nativeTrashHost as? NativeTrashHostController)?.apply(payload: call.arguments)
        }
        result(nil)
      case "nativeSearchResultsUpdated":
        if #available(iOS 26.0, *) {
          (self?.systemTabBarController as? DaftariSystemTabBarController)?.applySearchResults(payload: call.arguments)
        }
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
      // Search is an overlay. Keep the last real native content host visible
      // underneath it so UIKit never reveals Flutter during a transition.
      let visibleContentTabIndex = searchModeActive ? lastContentTabIndex : selectedTabIndex
      let homeSelected = visibleContentTabIndex == 0
      let shouldShowNativeDashboard =
        nativeDashboardInstalled &&
        navigationVisible &&
        homeSelected &&
        !flutterDetailVisible &&
        !nativeDetailVisible &&
        !nativeNoteDetailVisible &&
        !nativeSettingsVisible &&
        !nativeTrashVisible
      let shouldShowLegacyHeader =
        false

      setHost(
        nativeDashboardHost,
        visible: shouldShowNativeDashboard,
        interactive: shouldShowNativeDashboard && !searchModeActive
      )
      for (type, host) in nativeEntryHosts {
        let tabIndex: Int
        switch type {
        case .owedToMe: tabIndex = 1
        case .owedByMe: tabIndex = 2
        case .scratchpad: tabIndex = 3
        }
        let shouldShowEntryHost = (
          nativeDashboardInstalled &&
          navigationVisible &&
          visibleContentTabIndex == tabIndex &&
          !flutterDetailVisible &&
          !nativeDetailVisible &&
          !nativeNoteDetailVisible &&
          !nativeSettingsVisible &&
          !nativeTrashVisible
        )
        setHost(
          host,
          visible: shouldShowEntryHost,
          interactive: shouldShowEntryHost && !searchModeActive
        )
      }
      setHost(nativeEntryDetailsHost, visible: nativeDetailVisible, interactive: nativeDetailVisible)
      setHost(nativeNoteDetailsHost, visible: nativeNoteDetailVisible, interactive: nativeNoteDetailVisible)
      setHost(nativeSettingsHost, visible: nativeSettingsVisible, interactive: nativeSettingsVisible)
      setHost(nativeTrashHost, visible: nativeTrashVisible, interactive: nativeTrashVisible)
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

  private func setHost(
    _ host: UIViewController?,
    visible: Bool,
    interactive: Bool = true
  ) {
    guard let view = host?.view else { return }
    view.isHidden = !visible
    view.alpha = visible ? 1 : 0
    view.isUserInteractionEnabled = visible && interactive
  }

  @available(iOS 26.0, *)
  private func applyNativeSearchModeChange(_ active: Bool) {
    if active {
      guard searchState == .presenting else { return }
      searchState = .active
      if let systemTabs = systemTabBarController as? DaftariSystemTabBarController {
        // The system search host is already being presented by UIKit at this
        // point. Keep it above Flutter before changing the underlying surfaces.
        rootViewController.view.bringSubviewToFront(systemTabs.viewController.view)
      }
      // UISearchController owns the transition animation. Avoid a second
      // native fade here; this is one ordered visibility transaction.
      updateNativeSurfaceVisibility(animated: false)
      return
    }

    guard searchState == .active else { return }
    searchState = .dismissing
    selectedTabIndex = lastContentTabIndex
    (systemTabBarController as? DaftariSystemTabBarController)?.setSelectedTab(lastContentTabIndex)
  }

  private func updateLegacySearchMode(_ active: Bool) {
    guard #unavailable(iOS 26.0) else { return }
    guard active != searchModeActive else { return }
    searchState = active ? .active : .inactive
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func beginNativeSearchActivation(channel: FlutterMethodChannel?) {
    guard searchState == .inactive else { return }
    searchState = .presenting
    channel?.invokeMethod("nativeSearchActivated", arguments: nil)
  }

  @available(iOS 26.0, *)
  private func handleNativeTabSelection(_ index: Int, channel: FlutterMethodChannel?) {
    guard (0...3).contains(index) else { return }
    lastContentTabIndex = index
    selectedTabIndex = index
    if searchState != .inactive {
      searchState = .inactive
    }
    updateNativeSurfaceVisibility(animated: false)
    channel?.invokeMethod(
      NativeChannelConstants.NavigationMethod.nativeTabSelected,
      arguments: ["index": index]
    )
  }

  @available(iOS 26.0, *)
  private func finishNativeSearchDismissal(channel: FlutterMethodChannel?) {
    guard searchState == .dismissing else { return }
    searchState = .inactive
    updateNativeSurfaceVisibility(animated: false)
    channel?.invokeMethod("nativeSearchDismissed", arguments: nil)
  }

  @available(iOS 26.0, *)
  private func openNativeDetails(id: String) {
    guard !nativeDetailVisible, !flutterDetailVisible,
          let detailsHost = nativeEntryDetailsHost,
          let detailsBridge = nativeEntryDetailsBridge else { return }
    nativeDetailVisible = true
    navigationVisible = false
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(false, animated: true)
    setHost(detailsHost, visible: true, interactive: true)
    rootViewController.view.bringSubviewToFront(detailsHost.view)
    detailsBridge.load(id: id)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func openNativeNoteDetails(id: String) {
    guard !nativeDetailVisible, !nativeNoteDetailVisible, !flutterDetailVisible,
          let detailsHost = nativeNoteDetailsHost,
          let detailsBridge = nativeNoteDetailsBridge else { return }
    nativeNoteDetailVisible = true
    navigationVisible = false
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(false, animated: true)
    setHost(detailsHost, visible: true, interactive: true)
    rootViewController.view.bringSubviewToFront(detailsHost.view)
    detailsBridge.load(id: id)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func openNativeSettings() {
    guard !nativeSettingsVisible, !nativeDetailVisible, !nativeNoteDetailVisible,
          !flutterDetailVisible, let settingsHost = nativeSettingsHost else { return }
    nativeSettingsVisible = true
    navigationVisible = false
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(false, animated: true)
    setHost(settingsHost, visible: true, interactive: true)
    rootViewController.view.bringSubviewToFront(settingsHost.view)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func closeNativeSettings() {
    guard nativeSettingsVisible else { return }
    nativeSettingsVisible = false
    navigationVisible = true
    setHost(nativeSettingsHost, visible: false)
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(true, animated: true)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func restoreNativeSettings() {
    guard !nativeDetailVisible, !nativeNoteDetailVisible, !flutterDetailVisible,
          let settingsHost = nativeSettingsHost else { return }
    nativeSettingsVisible = true
    navigationVisible = false
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(false, animated: true)
    setHost(settingsHost, visible: true, interactive: true)
    rootViewController.view.bringSubviewToFront(settingsHost.view)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func openNativeTrash() {
    guard nativeSettingsVisible, !nativeTrashVisible,
          let trashHost = nativeTrashHost else { return }
    nativeSettingsVisible = false
    nativeTrashVisible = true
    setHost(trashHost, visible: true, interactive: true)
    rootViewController.view.bringSubviewToFront(trashHost.view)
    updateNativeSurfaceVisibility(animated: true)
    channel?.invokeMethod("nativeTrashLoad", arguments: nil) { [weak self] response in
      guard let self else { return }
      if let payload = response as? [String: Any] {
        (self.nativeTrashHost as? NativeTrashHostController)?.apply(payload: payload)
      } else if response is FlutterError {
        (self.nativeTrashHost as? NativeTrashHostController)?.presentError(message: "Unable to load Trash")
      }
    }
  }

  @available(iOS 26.0, *)
  private func closeNativeTrash() {
    guard nativeTrashVisible else { return }
    nativeTrashVisible = false
    setHost(nativeTrashHost, visible: false)
    restoreNativeSettings()
  }

  @available(iOS 26.0, *)
  private func requestTrashAction(method: String, id: String?) {
    guard !trashActionInFlight else { return }
    trashActionInFlight = true
    (nativeTrashHost as? NativeTrashHostController)?.setActionInFlight(true)
    let arguments = id.map { ["id": $0] }
    channel?.invokeMethod(method, arguments: arguments) { [weak self] response in
      guard let self else { return }
      self.trashActionInFlight = false
      (self.nativeTrashHost as? NativeTrashHostController)?.setActionInFlight(false)
      if let payload = response as? [String: Any] {
        (self.nativeTrashHost as? NativeTrashHostController)?.apply(payload: payload)
      } else if let error = response as? FlutterError {
        (self.nativeTrashHost as? NativeTrashHostController)?.presentError(message: error.message ?? "Operation failed")
      }
    }
  }

  @available(iOS 26.0, *)
  private func openFlutterTrash() {
    guard nativeSettingsVisible else { return }
    nativeSettingsVisible = false
    setHost(nativeSettingsHost, visible: false)
    channel?.invokeMethod("nativeSettingsOpenTrash", arguments: nil)
  }

  @available(iOS 26.0, *)
  private func requestSettingsExport() {
    channel?.invokeMethod("nativeSettingsExport", arguments: nil) { [weak self] response in
      guard let self, let payload = response as? [String: Any],
            let json = payload["json"] as? String else {
        if let self { NativeSettingsBridge.presentError(on: self.rootViewController, message: "Export failed") }
        return
      }
      let name = payload["fileName"] as? String ?? "daftari_backup.json"
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      do {
        try json.data(using: .utf8)?.write(to: url, options: .atomic)
        (self.nativeSettingsHost as? NativeSettingsHostController)?.presentExport(url: url)
      } catch {
        NativeSettingsBridge.presentError(on: self.rootViewController, message: "Export failed")
      }
    }
  }

  @available(iOS 26.0, *)
  private func requestSettingsImportPreview(contents: String) {
    channel?.invokeMethod("nativeSettingsImportPreview", arguments: ["contents": contents]) { [weak self] response in
      guard let self else { return }
      guard let payload = response as? [String: Any],
            let conflicts = payload["conflictingEntries"] as? Int else {
        NativeSettingsBridge.presentError(on: self.rootViewController, message: "Import failed")
        return
      }
      if conflicts == 0 {
        self.performSettingsImport(contents: contents, strategy: "skipExisting")
        return
      }
      let alert = UIAlertController(
        title: "Import Conflicts",
        message: "This backup contains \(conflicts) entries already on this device.",
        preferredStyle: .alert
      )
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
      alert.addAction(UIAlertAction(title: "Skip Existing", style: .default) { [weak self] _ in
        self?.performSettingsImport(contents: contents, strategy: "skipExisting")
      })
      alert.addAction(UIAlertAction(title: "Replace Existing", style: .default) { [weak self] _ in
        self?.performSettingsImport(contents: contents, strategy: "replaceExisting")
      })
      (self.nativeSettingsHost ?? self.rootViewController).present(alert, animated: true)
    }
  }

  @available(iOS 26.0, *)
  private func performSettingsImport(contents: String, strategy: String) {
    channel?.invokeMethod("nativeSettingsImport", arguments: [
      "contents": contents,
      "strategy": strategy,
    ]) { [weak self] response in
      if let error = response as? FlutterError, let self {
        NativeSettingsBridge.presentError(on: self.rootViewController, message: error.message ?? "Import failed")
      }
    }
  }

  @available(iOS 26.0, *)
  private func requestSettingsMutation(method: String) {
    channel?.invokeMethod(method, arguments: nil) { [weak self] response in
      if let error = response as? FlutterError, let self {
        NativeSettingsBridge.presentError(on: self.rootViewController, message: error.message ?? "Operation failed")
      }
    }
  }

  @available(iOS 26.0, *)
  private func closeNativeDetails() {
    guard nativeDetailVisible else { return }
    nativeDetailVisible = false
    navigationVisible = true
    setHost(nativeEntryDetailsHost, visible: false)
    (systemTabBarController as? DaftariSystemTabBarController)?.setNavigationVisible(true, animated: true)
    updateNativeSurfaceVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func closeNativeNoteDetails() {
    guard nativeNoteDetailVisible else { return }
    nativeNoteDetailVisible = false
    navigationVisible = true
    setHost(nativeNoteDetailsHost, visible: false)
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
    setHost(detailsHost, visible: true, interactive: true)
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
