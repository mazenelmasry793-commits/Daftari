import UIKit

@available(iOS 26.0, *)
final class DaftariSystemTabBarController: NSObject, UITabBarControllerDelegate {
  let viewController: UITabBarController

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
  private let searchHost: DaftariSearchHostViewController
  private let searchNavigationController: UINavigationController
  private let addButton = UIButton(type: .system)
  private let accessoryContainer = UIView()
  private let searchTab: UISearchTab
  private var tabsByIdentifier: [String: Int] = [:]
  private var searchIsActive = false

  init(
    onTabSelected: @escaping (Int) -> Void,
    onSearchActivated: @escaping () -> Void,
    onSearchQueryChanged: @escaping (String) -> Void,
    onSearchDismissed: @escaping () -> Void,
    onSearchModeChanged: @escaping (Bool) -> Void,
    onAddEntryTypeSelected: @escaping (String) -> Void
  ) {
    self.onTabSelected = onTabSelected
    self.onSearchActivated = onSearchActivated
    self.onSearchModeChanged = onSearchModeChanged

    let host = DaftariSearchHostViewController(
      onQueryChanged: onSearchQueryChanged,
      onDismissed: onSearchDismissed
    )
    self.searchHost = host
    let searchNavigationController = UINavigationController(rootViewController: host)
    searchNavigationController.setNavigationBarHidden(true, animated: false)
    self.searchNavigationController = searchNavigationController

    let normalTabs: [(String, String, String)] = [
      ("Home", "square.grid.2x2.fill", "home"),
      ("To Me", "arrow.down.left.circle", "owed-to-me"),
      ("I Owe", "arrow.up.right.circle", "owed-by-me"),
      ("Notes", "note.text", "notes"),
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

    let controller = UITabBarController(tabs: allTabs)
    controller.mode = .tabBar
    if #available(iOS 26.0, *) {
      controller.tabBarMinimizeBehavior = .never
    }
    controller.view.backgroundColor = .clear
    controller.view.isOpaque = false
    self.viewController = controller
    super.init()

    controller.delegate = self
    host.onSearchBegan = { [weak self] in
      self?.setSearchActive(true)
    }
    host.onSearchEnded = { [weak self] in
      self?.setSearchActive(false)
    }
    configureAddButton(onAddEntryTypeSelected: onAddEntryTypeSelected)
    if #available(iOS 26.0, *) {
      accessoryContainer.translatesAutoresizingMaskIntoConstraints = false
      accessoryContainer.addSubview(addButton)
      NSLayoutConstraint.activate([
        accessoryContainer.widthAnchor.constraint(equalToConstant: 52),
        accessoryContainer.heightAnchor.constraint(equalToConstant: 52),
        addButton.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
        addButton.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
        addButton.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
        addButton.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor),
      ])
      controller.bottomAccessory = UITabAccessory(contentView: accessoryContainer)
    }
  }

  func setNavigationVisible(_ visible: Bool, animated: Bool) {
    let update = {
      self.viewController.isTabBarHidden = !visible
      self.accessoryContainer.isHidden = !visible || self.searchIsActive
      self.viewController.view.isUserInteractionEnabled = visible
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      update()
      return
    }
    UIView.animate(withDuration: 0.2, animations: update)
  }

  func setSelectedTab(_ index: Int) {
    guard index >= 0, index < viewController.tabs.count else { return }
    viewController.selectedTab = viewController.tabs[index]
  }

  func activateSearchTab() {
    guard !searchIsActive else { return }
    viewController.selectedTab = searchTab
  }

  func setSearchVisible(_ visible: Bool) {
    if visible { activateSearchTab() }
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelectTab selectedTab: UITab,
    previousTab: UITab?
  ) {
    guard let index = tabsByIdentifier[selectedTab.identifier] else { return }
    if selectedTab.identifier == searchTab.identifier {
      onSearchActivated()
      setSearchActive(true)
    } else {
      onTabSelected(index)
    }
  }

  private func setSearchActive(_ active: Bool) {
    guard searchIsActive != active else { return }
    searchIsActive = active
    accessoryContainer.isHidden = active
    addButton.isUserInteractionEnabled = !active
    onSearchModeChanged(active)
  }

  private func configureAddButton(onAddEntryTypeSelected: @escaping (String) -> Void) {
    addButton.translatesAutoresizingMaskIntoConstraints = false
    let image = UIImage(
      systemName: "plus",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    )
    var configuration = UIButton.Configuration.clearGlass()
    configuration.image = image
    configuration.baseForegroundColor = .label
    addButton.configuration = configuration
    addButton.accessibilityLabel = "Add entry"
    addButton.accessibilityHint = "Opens the new entry menu"
    addButton.showsMenuAsPrimaryAction = true
    addButton.menu = UIMenu(
      title: "",
      children: [
        NativeAddEntryOption.scratchpad,
        NativeAddEntryOption.owedByMe,
        NativeAddEntryOption.owedToMe,
      ].map { option in
        let action = UIAction(
          title: option.title,
          image: UIImage(systemName: option.sfSymbolName)
        ) { _ in
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
          onAddEntryTypeSelected(option.rawValue)
        }
        if #available(iOS 15.0, *) {
          action.subtitle = option.subtitle
        }
        return action
      }
    )
  }
}
