import UIKit

@available(iOS 26.0, *)
final class DaftariSystemTabBarController: NSObject, UITabBarControllerDelegate {
  let viewController: DaftariPassthroughTabBarController

  private final class PlaceholderViewController: UIViewController {
    override func loadView() {
      let view = UIView()
      view.backgroundColor = .clear
      view.isOpaque = false
      view.isUserInteractionEnabled = false
      self.view = view
    }
  }

  private let onTabSelected: (Int) -> Void
  private let onSearchActivated: () -> Void
  private let onSearchModeChanged: (Bool) -> Void
  private let onSearchResultSelected: (String, String) -> Void
  private let searchHost: DaftariSearchHostViewController
  private let searchNavigationController: UINavigationController
  private let searchTab: UISearchTab
  private var tabsByIdentifier: [String: Int] = [:]
  private var pendingProgrammaticTabIndex: Int?
  private var searchActivationInProgress = false
  private var pendingSearchResult: (id: String, type: String)?

  init(
    onTabSelected: @escaping (Int) -> Void,
    onSearchActivated: @escaping () -> Void,
    onSearchQueryChanged: @escaping (String) -> Void,
    onSearchDismissed: @escaping () -> Void,
    onSearchModeChanged: @escaping (Bool) -> Void,
    onSearchResultSelected: @escaping (String, String) -> Void
  ) {
    self.onTabSelected = onTabSelected
    self.onSearchActivated = onSearchActivated
    self.onSearchModeChanged = onSearchModeChanged
    self.onSearchResultSelected = onSearchResultSelected

    let host = DaftariSearchHostViewController(
      onQueryChanged: onSearchQueryChanged,
      onDismissed: onSearchDismissed,
      onResultSelected: { _, _ in }
    )
    self.searchHost = host
    let searchNavigationController = UINavigationController(rootViewController: host)
    searchNavigationController.setNavigationBarHidden(true, animated: false)
    self.searchNavigationController = searchNavigationController

    let normalTabs: [(String, String, String)] = [
      ("Home", "square.grid.2x2.fill", "home"),
      ("To Me", "arrow.down.left.circle", "owed-to-me"),
      ("I Owe", "arrow.up.right.circle", "owed-by-me"),
    ]
    let normalTabObjects = normalTabs.map { title, symbol, identifier in
      UITab(
        title: title,
        image: UIImage(systemName: symbol),
        identifier: identifier
      ) { _ in PlaceholderViewController() }
    }
    self.searchTab = UISearchTab { _ in searchNavigationController }
    if #available(iOS 26.0, *) {
      searchTab.automaticallyActivatesSearch = true
    }

    var allTabs = normalTabObjects.map { $0 as UITab }
    allTabs.append(searchTab)
    for (index, tab) in allTabs.enumerated() {
      tabsByIdentifier[tab.identifier] = index
    }

    let controller = DaftariPassthroughTabBarController(tabs: allTabs)
    controller.interactionMode = .contentTabs
    controller.selectedTab = allTabs[0]
    if #available(iOS 26.0, *) {
      controller.tabBarMinimizeBehavior = .never
    }
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    self.viewController = controller
    super.init()

    host.onResultSelected = { [weak self] id, type in
      guard let self, self.pendingSearchResult == nil else { return }
      self.pendingSearchResult = (id, type)
      onSearchResultSelected(id, type)
      self.searchHost.requestDismissal()
    }

    controller.delegate = self
    host.onSearchBegan = { [weak self] in
      guard let self else { return }
      self.enterSearchInteractionMode(source: "willPresent")
      self.setSearchActive(true)
    }
    host.onSearchDismissalBegan = { [weak self] in
      self?.setSearchActive(false)
    }
  }

  func setNavigationVisible(_ visible: Bool, animated: Bool) {
    let update = {
      self.viewController.setTabBarHidden(!visible, animated: false)
      // Keep the full-screen passthrough container interactive. It must be
      // able to return nil outside the tab bar so Flutter/native hosts below
      // remain tappable.
      self.viewController.tabBar.isUserInteractionEnabled = visible
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      update()
      return
    }
    UIView.animate(withDuration: 0.2, animations: update)
  }

  func setSelectedTab(_ index: Int) {
    guard index >= 0, index < viewController.tabs.count else { return }
    let target = viewController.tabs[index]
    guard viewController.selectedTab !== target else { return }
    pendingProgrammaticTabIndex = index
    viewController.selectedTab = target
  }

  func activateSearchTab() {
    guard viewController.selectedTab !== searchTab else { return }
    // A programmatic content-tab selection from an earlier lifecycle must not
    // consume the next real Search callback after the controller is reused.
    pendingProgrammaticTabIndex = nil
    searchHost.prepareForActivation()
    enterSearchInteractionMode(source: "programmatic")
    searchActivationInProgress = true
    onSearchActivated()
    viewController.selectedTab = searchTab
  }

  func setSearchVisible(_ visible: Bool) {
    if visible { activateSearchTab() }
  }

  func applySearchResults(payload: Any?) {
    searchHost.applyResults(payload: payload)
  }

  func consumePendingSearchResult() -> (id: String, type: String)? {
    defer { pendingSearchResult = nil }
    return pendingSearchResult
  }

  func restoreContentInteraction() {
    setInteractionMode(.contentTabs, source: "didDismiss")
  }

  private func enterSearchInteractionMode(source: String) {
    setInteractionMode(.searchFullScreen, source: source)
  }

  private func setInteractionMode(
    _ mode: DaftariTabBarInteractionMode,
    source: String
  ) {
    guard viewController.interactionMode != mode else { return }
    viewController.interactionMode = mode
#if DEBUG
    let name = mode == .searchFullScreen ? "searchFullScreen" : "contentTabs"
    print("Search interaction → \(name), source=\(source)")
#endif
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelectTab selectedTab: UITab,
    previousTab: UITab?
  ) {
    if previousTab?.identifier == searchTab.identifier,
       selectedTab.identifier != searchTab.identifier {
      searchHost.endSearchEditing()
    }
    if selectedTab.identifier == searchTab.identifier {
      enterSearchInteractionMode(source: "manualTab")
    }
    guard let index = tabsByIdentifier[selectedTab.identifier] else { return }
    if pendingProgrammaticTabIndex == index {
      pendingProgrammaticTabIndex = nil
      return
    }
    if pendingProgrammaticTabIndex != nil {
      pendingProgrammaticTabIndex = nil
    }
    if selectedTab.identifier == searchTab.identifier {
      if searchActivationInProgress {
        searchActivationInProgress = false
      } else {
        onSearchActivated()
      }
    } else {
      searchActivationInProgress = false
      onTabSelected(index)
    }
  }

  private func setSearchActive(_ active: Bool) {
    // UIKit can report the same presentation state more than once when a
    // reused UISearchController is activated again. The coordinator owns the
    // lifecycle transition guard; this callback remains notification-only.
    onSearchModeChanged(active)
  }
}

@available(iOS 26.0, *)
final class DaftariPassthroughTabBarController: UITabBarController {
  var interactionMode: DaftariTabBarInteractionMode = .contentTabs {
    didSet {
      (view as? DaftariTabBarPassthroughView)?.interactionMode = interactionMode
    }
  }

  override func loadView() {
    // Keep UIKit's internal UITabBarController hierarchy intact. Replacing
    // its root view directly leaves the system tab bar's private container
    // without the layout context it expects and can place the bar off-screen.
    super.loadView()
    guard let systemView = view else { return }
    let passthroughView = DaftariTabBarPassthroughView(frame: systemView.bounds)
    passthroughView.interactionMode = interactionMode
    passthroughView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    passthroughView.backgroundColor = .clear
    passthroughView.isOpaque = false
    systemView.frame = passthroughView.bounds
    systemView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    systemView.backgroundColor = .clear
    systemView.isOpaque = false
    passthroughView.addSubview(systemView)
    view = passthroughView
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    (view as? DaftariTabBarPassthroughView)?.interactiveView = tabBar
  }
}

@available(iOS 26.0, *)
enum DaftariTabBarInteractionMode: Equatable {
  case contentTabs
  case searchFullScreen
}

@available(iOS 26.0, *)
private final class DaftariTabBarPassthroughView: UIView {
  weak var interactiveView: UIView?
  var interactionMode: DaftariTabBarInteractionMode = .contentTabs

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if interactionMode == .searchFullScreen {
      return super.hitTest(point, with: event)
    }
    guard !isHidden, alpha > 0.01, isUserInteractionEnabled,
          let interactiveView,
          !interactiveView.isHidden,
          interactiveView.alpha > 0.01,
          interactiveView.isUserInteractionEnabled else { return nil }
    let tabBarPoint = convert(point, to: interactiveView)
    guard interactiveView.point(inside: tabBarPoint, with: event) else { return nil }
    return interactiveView.hitTest(tabBarPoint, with: event)
  }
}
