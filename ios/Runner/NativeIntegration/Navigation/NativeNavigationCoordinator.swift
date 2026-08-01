import Flutter
import UIKit

final class NativeNavigationCoordinator {
  private let rootViewController: FlutterViewController
  private let sheetCoordinator: NativeSheetCoordinator
  private var channel: FlutterMethodChannel?
  private var navigationView: NativeFloatingNavigationView?
  private var systemTabBarController: AnyObject?
  private var navigationBarHost: AnyObject?
  private var settingsButton: NativeSettingsButtonView?
  private var dashboardAddItem: UIBarButtonItem?
  private var dashboardSettingsItem: UIBarButtonItem?
  private var dashboardTitle = "Dashboard"
  private var dashboardTitleCollapsed = false
  private var navigationVisible = false
  private var searchModeActive = false
  private let titleCollapseThreshold: CGFloat = 24
  private let titleExpandThreshold: CGFloat = 4
  // Keeps the native control clear of the screen edge while preserving its
  // safe-area-aligned header position.
  private let settingsButtonTrailingInset: CGFloat = 8

  init(rootViewController: FlutterViewController, sheetCoordinator: NativeSheetCoordinator) {
    self.rootViewController = rootViewController
    self.sheetCoordinator = sheetCoordinator
    self.sheetCoordinator.onRequestAddEntryMenu = { [weak self] in
      self?.navigationView?.presentAddMenu()
      if #available(iOS 26.0, *) {
        self?.presentNativeDashboardAddMenu()
      }
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
        self?.setSearchMode(active)
      }
    )
    settingsButton.onSettingsRequested = { [weak channel] in
      channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
    }
    if #available(iOS 26.0, *) {
      let systemTabs = DaftariSystemTabBarController(
        onTabSelected: { [weak channel] index in
          channel?.invokeMethod(
            NativeChannelConstants.NavigationMethod.nativeTabSelected,
            arguments: ["index": index]
          )
        },
        onSearchActivated: { [weak channel] in
          channel?.invokeMethod("nativeSearchActivated", arguments: nil)
        },
        onSearchQueryChanged: { [weak channel] query in
          channel?.invokeMethod("nativeSearchQueryChanged", arguments: query)
        },
        onSearchDismissed: { [weak channel] in
          channel?.invokeMethod("nativeSearchDismissed", arguments: nil)
        },
        onSearchModeChanged: { [weak self] active in
          self?.setSearchMode(active)
        }
      )
      rootViewController.addChild(systemTabs.viewController)
      rootViewController.view.addSubview(systemTabs.viewController.view)
      systemTabs.viewController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        systemTabs.viewController.view.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor),
        systemTabs.viewController.view.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor),
        systemTabs.viewController.view.topAnchor.constraint(equalTo: rootViewController.view.safeAreaLayoutGuide.topAnchor),
        systemTabs.viewController.view.bottomAnchor.constraint(equalTo: rootViewController.view.bottomAnchor),
      ])
      systemTabs.viewController.didMove(toParent: rootViewController)
      self.systemTabBarController = systemTabs
      configureDashboardNavigationBar(channel: channel)
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

    if #available(iOS 26.0, *) {
      // Dashboard actions are owned by the real UINavigationItem above.
    } else {
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
          (self?.systemTabBarController as? DaftariSystemTabBarController)?.setSelectedTab(index)
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
        self?.updateSettingsVisibility(animated: true)
        result(nil)
      case "setNavigationTitle":
        self?.setDashboardTitle(arguments?["title"] as? String ?? "Dashboard")
        result(nil)
      case "dashboardScrollOffsetChanged":
        self?.updateDashboardScrollOffset(arguments?["offset"] as? CGFloat ?? 0)
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.channel = channel
    self.navigationView = navigationView
    self.settingsButton = settingsButton
  }

  private func updateSettingsVisibility(animated: Bool) {
    if #available(iOS 26.0, *) {
      setNativeDashboardItemsVisible(navigationVisible && !searchModeActive, animated: animated)
    } else {
      settingsButton?.setVisible(navigationVisible && !searchModeActive, animated: animated)
    }
  }

  private func setSearchMode(_ active: Bool) {
    searchModeActive = active
    if #available(iOS 26.0, *) {
      rootViewController.navigationItem.title = active ? nil : dashboardTitle
      if !active {
        rootViewController.navigationItem.largeTitleDisplayMode = dashboardTitle == "Dashboard" && !dashboardTitleCollapsed ? .always : .automatic
      }
    }
    updateSettingsVisibility(animated: true)
  }

  @available(iOS 26.0, *)
  private func configureDashboardNavigationBar(channel: FlutterMethodChannel) {
    guard let navigationController = rootViewController.navigationController else { return }
    navigationController.navigationBar.prefersLargeTitles = true
    rootViewController.navigationItem.title = dashboardTitle
    rootViewController.navigationItem.largeTitleDisplayMode = .always

    let add = UIBarButtonItem(
      image: UIImage(systemName: "plus"),
      style: .plain,
      target: self,
      action: nil
    )
    add.accessibilityLabel = "Add entry"
    add.accessibilityHint = "Opens the new entry menu"
    add.menu = makeAddMenu()

    let settings = UIBarButtonItem(
      image: UIImage(systemName: "gearshape.fill"),
      style: .plain,
      target: self,
      action: #selector(nativeSettingsTapped)
    )
    settings.accessibilityLabel = "Settings"
    rootViewController.navigationItem.rightBarButtonItems = [settings, add]
    dashboardAddItem = add
    dashboardSettingsItem = settings
    navigationBarHost = navigationController
    navigationController.setNavigationBarHidden(false, animated: false)

    let standard = UINavigationBarAppearance()
    standard.configureWithDefaultBackground()
    let scrollEdge = UINavigationBarAppearance()
    // Flutter's body is not a native UIScrollView, so a fully transparent
    // scroll-edge bar would reveal the Flutter engine's black backing view.
    // Default system material keeps the large title readable while retaining
    // Apple's native appearance and transition.
    scrollEdge.configureWithDefaultBackground()
    standard.backgroundColor = .systemBackground
    scrollEdge.backgroundColor = .systemBackground
    standard.titleTextAttributes = [.foregroundColor: UIColor.label]
    standard.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
    scrollEdge.titleTextAttributes = [.foregroundColor: UIColor.label]
    scrollEdge.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
    navigationController.navigationBar.standardAppearance = standard
    navigationController.navigationBar.scrollEdgeAppearance = scrollEdge
    navigationController.navigationBar.compactAppearance = standard
    if #available(iOS 15.0, *) {
      navigationController.navigationBar.compactScrollEdgeAppearance = scrollEdge
    }
    _ = channel
  }

  @available(iOS 26.0, *)
  private func makeAddMenu() -> UIMenu {
    UIMenu(
      title: "",
      children: NativeAddEntryOption.allCases.map { option in
        let action = UIAction(
          title: option.title,
          image: UIImage(systemName: option.sfSymbolName)
        ) { [weak self] _ in
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          _ = self?.sheetCoordinator.presentNativeEntryForm(type: option.rawValue)
        }
        if #available(iOS 15.0, *) { action.subtitle = option.subtitle }
        return action
      }
    )
  }

  @available(iOS 26.0, *)
  private func presentNativeDashboardAddMenu() {
    dashboardAddItem?.menu = makeAddMenu()
  }

  @available(iOS 26.0, *)
  private func setNativeDashboardItemsVisible(_ visible: Bool, animated: Bool) {
    guard let navigationController = rootViewController.navigationController else { return }
    let update = {
      self.rootViewController.navigationItem.rightBarButtonItems = visible
        ? [self.dashboardSettingsItem, self.dashboardAddItem].compactMap { $0 }
        : nil
      navigationController.navigationBar.isUserInteractionEnabled = visible
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else { update(); return }
    UIView.animate(withDuration: 0.2, animations: update)
  }

  private func setDashboardTitle(_ title: String) {
    dashboardTitle = title
    guard #available(iOS 26.0, *), !searchModeActive else { return }
    rootViewController.navigationItem.title = title
    rootViewController.navigationController?.navigationBar.topItem?.title = title
    rootViewController.navigationItem.largeTitleDisplayMode = title == "Dashboard" && !dashboardTitleCollapsed ? .always : .automatic
  }

  private func updateDashboardScrollOffset(_ offset: CGFloat) {
    guard #available(iOS 26.0, *), dashboardTitle == "Dashboard", !searchModeActive else { return }
    let shouldCollapse = dashboardTitleCollapsed
      ? offset > titleExpandThreshold
      : offset >= titleCollapseThreshold
    guard shouldCollapse != dashboardTitleCollapsed else { return }
    dashboardTitleCollapsed = shouldCollapse
    rootViewController.navigationItem.title = dashboardTitle
    rootViewController.navigationController?.navigationBar.topItem?.title = dashboardTitle
    // Automatic keeps the same native item but lets UIKit render its compact
    // inline title while the Flutter scroll view is away from the top.
    rootViewController.navigationItem.largeTitleDisplayMode = shouldCollapse ? .automatic : .always
    guard let navigationBar = rootViewController.navigationController?.navigationBar else { return }
    if shouldCollapse {
      navigationBar.scrollEdgeAppearance = navigationBar.standardAppearance
    } else {
      let scrollEdge = UINavigationBarAppearance()
      scrollEdge.configureWithDefaultBackground()
      navigationBar.scrollEdgeAppearance = scrollEdge
    }
    UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.22) {
      navigationBar.layoutIfNeeded()
    }
  }

  @available(iOS 26.0, *)
  @objc private func nativeSettingsTapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    channel?.invokeMethod(NativeChannelConstants.NavigationMethod.openSettings, arguments: nil)
  }

  deinit {
    channel?.setMethodCallHandler(nil)
  }
}
