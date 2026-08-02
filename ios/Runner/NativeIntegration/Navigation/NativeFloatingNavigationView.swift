import UIKit

final class NativeFloatingNavigationView: UIView, UITabBarDelegate {
  private enum SearchState {
    case normal
    case entering
    case searching
    case exiting
  }

  private let onTabSelected: (Int) -> Void
  private let onAddEntryTypeSelected: (String) -> Void
  private let onSearchQueryChanged: (String) -> Void
  private let onSearchDismissed: () -> Void
  private let onSearchModeChanged: (Bool) -> Void
  private let tabBar = UITabBar()
  private let addButton = UIButton(type: .system)
  private let searchBar = NativeSearchBarView()
  private let rowContainer = UIView()
  private let groupContainer = UIView()
  // iOS 26's native Liquid Glass platter reserves 21 pt on each horizontal
  // side. The 16 pt visible gap keeps the platter and + control distinct.
  private let liquidGlassHorizontalInset: CGFloat = 21
  private let visibleTabBarButtonGap: CGFloat = 16
  // The platter's 21 pt leading inset shifts the visible group right by half
  // that amount, so the responsive parent group is centered with this offset.
  private let liquidGlassCenteringCompensation: CGFloat = -10.5
  // A subtle, shared downward shift that keeps both native controls together.
  private let bottomNavigationLowering: CGFloat = 4
  private var wantsVisible = false
  private var keyboardVisible = false
  private var searchState: SearchState = .normal
  private var searchAnimator: UIViewPropertyAnimator?
  private var searchTransitionToken = 0
  private let searchAnimationDuration: TimeInterval = 0.34
  private let searchSpringDamping: CGFloat = 0.92

  init(
    onTabSelected: @escaping (Int) -> Void,
    onAddEntryTypeSelected: @escaping (String) -> Void,
    onSearchQueryChanged: @escaping (String) -> Void,
    onSearchDismissed: @escaping () -> Void,
    onSearchModeChanged: @escaping (Bool) -> Void
  ) {
    self.onTabSelected = onTabSelected
    self.onAddEntryTypeSelected = onAddEntryTypeSelected
    self.onSearchQueryChanged = onSearchQueryChanged
    self.onSearchDismissed = onSearchDismissed
    self.onSearchModeChanged = onSearchModeChanged
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    isHidden = true
    alpha = 0
    backgroundColor = .clear
    setupViews()
    searchBar.onQueryChanged = { [weak self] query in
      self?.onSearchQueryChanged(query)
    }
    observeKeyboard()
    updateVisibility(animated: false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    searchAnimator?.stopAnimation(true)
    NotificationCenter.default.removeObserver(self)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard wantsVisible && !isHidden else { return false }
    let containerPoint = convert(point, to: rowContainer)
    return rowContainer.point(inside: containerPoint, with: event)
  }

  private func setupViews() {
    tabBar.delegate = self
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.itemPositioning = .fill

    let dashItem = UITabBarItem(title: "Home", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 0)
    dashItem.accessibilityLabel = "Dashboard"
    let owedToMeItem = UITabBarItem(title: "To Me", image: UIImage(systemName: "arrow.down.left.circle"), tag: 1)
    owedToMeItem.accessibilityLabel = "Owed To Me"
    let owedByMeItem = UITabBarItem(title: "I Owe", image: UIImage(systemName: "arrow.up.right.circle"), tag: 2)
    owedByMeItem.accessibilityLabel = "Owed By Me"
    let searchItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 3)
    searchItem.accessibilityLabel = "Search"
    let items = [dashItem, owedToMeItem, owedByMeItem, searchItem]
    tabBar.items = items
    tabBar.selectedItem = items.first

    addButton.translatesAutoresizingMaskIntoConstraints = false
    configureActionButton(forSearchMode: false)

    rowContainer.translatesAutoresizingMaskIntoConstraints = false
    rowContainer.backgroundColor = .clear
    groupContainer.translatesAutoresizingMaskIntoConstraints = false
    groupContainer.backgroundColor = .clear
    rowContainer.addSubview(groupContainer)
    groupContainer.addSubview(tabBar)
    groupContainer.addSubview(searchBar)
    groupContainer.addSubview(addButton)
    addSubview(rowContainer)
    NSLayoutConstraint.activate([
      rowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      rowContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
      rowContainer.bottomAnchor.constraint(
        equalTo: safeAreaLayoutGuide.bottomAnchor,
        constant: bottomNavigationLowering
      ),
      rowContainer.heightAnchor.constraint(equalToConstant: 83),
      groupContainer.widthAnchor.constraint(equalTo: rowContainer.widthAnchor),
      groupContainer.centerXAnchor.constraint(
        equalTo: rowContainer.centerXAnchor,
        constant: liquidGlassCenteringCompensation
      ),
      groupContainer.topAnchor.constraint(equalTo: rowContainer.topAnchor),
      groupContainer.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
      tabBar.leadingAnchor.constraint(equalTo: groupContainer.leadingAnchor),
      tabBar.trailingAnchor.constraint(
        equalTo: addButton.leadingAnchor,
        constant: liquidGlassHorizontalInset - visibleTabBarButtonGap
      ),
      tabBar.topAnchor.constraint(equalTo: groupContainer.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: groupContainer.bottomAnchor),
      // Match the tab bar's measured Liquid Glass platter inset so the
      // search field occupies the same visible pill, not the outer UITabBar
      // frame.
      searchBar.leadingAnchor.constraint(
        equalTo: tabBar.leadingAnchor,
        constant: liquidGlassHorizontalInset
      ),
      searchBar.trailingAnchor.constraint(
        equalTo: tabBar.trailingAnchor,
        constant: -liquidGlassHorizontalInset
      ),
      searchBar.topAnchor.constraint(equalTo: tabBar.topAnchor),
      searchBar.bottomAnchor.constraint(equalTo: tabBar.bottomAnchor),
      addButton.trailingAnchor.constraint(equalTo: groupContainer.trailingAnchor),
      addButton.centerYAnchor.constraint(equalTo: tabBar.topAnchor, constant: 31),
      addButton.widthAnchor.constraint(equalToConstant: 52),
      addButton.heightAnchor.constraint(equalToConstant: 52),
    ])
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    UISelectionFeedbackGenerator().selectionChanged()
    if item.tag == 4 {
      enterSearchMode()
    }
    onTabSelected(item.tag)
  }

  @objc private func addTapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
  }

  @objc private func closeSearchTapped() {
    guard searchState == .entering || searchState == .searching else { return }
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    exitSearchMode(notify: true)
  }

  private func configureActionButton(forSearchMode searchMode: Bool) {
    addButton.removeTarget(nil, action: nil, for: .allEvents)
    if #available(iOS 14.0, *) {
      addButton.menu = nil
      addButton.showsMenuAsPrimaryAction = false
    }
    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    let symbolName = searchMode ? "xmark" : "plus"
    let image = UIImage(systemName: symbolName, withConfiguration: symbolConfiguration)
    addButton.accessibilityLabel = searchMode ? "Close search" : "Add entry"
    addButton.accessibilityHint = searchMode ? nil : "Opens the new entry menu"

    if #available(iOS 26.0, *) {
      var config = UIButton.Configuration.clearGlass()
      config.image = image
      config.baseForegroundColor = .label
      addButton.configuration = config
    } else if #available(iOS 15.0, *) {
      var config = UIButton.Configuration.tinted()
      config.image = image
      config.cornerStyle = .capsule
      config.baseForegroundColor = .label
      addButton.configuration = config
    } else {
      addButton.setImage(image, for: .normal)
      addButton.tintColor = .label
      addButton.layer.cornerRadius = 26
    }

    if searchMode {
      addButton.addTarget(self, action: #selector(closeSearchTapped), for: .touchUpInside)
    } else {
      addButton.addTarget(self, action: #selector(addTapped), for: .touchDown)
      if #available(iOS 14.0, *) {
        addButton.showsMenuAsPrimaryAction = true
        addButton.menu = makeAddMenu()
      } else {
        addButton.addTarget(self, action: #selector(addMenuUnsupported), for: .touchUpInside)
      }
    }
  }

  private func enterSearchMode() {
    guard searchState == .normal else { return }
    searchState = .entering
    onSearchModeChanged(true)
    searchBar.setSearchVisible(true, animated: false)
    searchBar.alpha = 0
    tabBar.isUserInteractionEnabled = false
    configureActionButton(forSearchMode: true)
    animateSearchTransition(entering: true)
  }

  func setSearchVisible(_ visible: Bool) {
    if visible {
      enterSearchMode()
    } else if searchState == .searching || searchState == .entering {
      exitSearchMode(notify: false)
    }
  }

  private func exitSearchMode(notify: Bool) {
    guard searchState == .searching || searchState == .entering else { return }
    searchState = .exiting
    onSearchModeChanged(false)
    searchBar.setSearchVisible(false, animated: false)
    tabBar.isUserInteractionEnabled = false
    configureActionButton(forSearchMode: false)
    animateSearchTransition(entering: false)
    if notify {
      onSearchDismissed()
    }
  }

  private func animateSearchTransition(entering: Bool) {
    searchTransitionToken += 1
    let transitionToken = searchTransitionToken
    searchAnimator?.stopAnimation(true)
    searchAnimator = nil
    layoutIfNeeded()
    searchBar.layoutIfNeeded()

    let changes = {
      self.tabBar.alpha = entering ? 0 : 1
      self.searchBar.alpha = entering ? 1 : 0
      self.addButton.transform = entering
        ? CGAffineTransform(scaleX: 0.96, y: 0.96)
        : .identity
    }
    searchBar.isHidden = false
    tabBar.isHidden = false
    if UIAccessibility.isReduceMotionEnabled {
      changes()
      finishSearchTransition(entering: entering, token: transitionToken)
    } else {
      let animator = UIViewPropertyAnimator(
        duration: searchAnimationDuration,
        timingParameters: UISpringTimingParameters(dampingRatio: searchSpringDamping)
      )
      animator.addAnimations(changes)
      animator.addCompletion { [weak self] position in
        guard position == .end else { return }
        self?.finishSearchTransition(entering: entering, token: transitionToken)
      }
      searchAnimator = animator
      animator.startAnimation()
    }
  }

  private func finishSearchTransition(entering: Bool, token: Int) {
    guard token == searchTransitionToken else { return }
    searchAnimator = nil
    addButton.transform = .identity
    if entering {
      tabBar.alpha = 0
      tabBar.isHidden = true
      tabBar.isUserInteractionEnabled = false
      searchBar.finalizeVisibleState()
      searchState = .searching
    } else {
      searchBar.finalizeHiddenState()
      tabBar.alpha = 1
      tabBar.isHidden = false
      tabBar.isUserInteractionEnabled = true
      searchState = .normal
    }
    layoutIfNeeded()
  }

  @available(iOS 14.0, *)
  private func makeAddMenu() -> UIMenu {
    let actions = [
      NativeAddEntryOption.owedByMe,
      NativeAddEntryOption.owedToMe,
    ].map { option in
      let action = UIAction(
        title: option.title,
        image: UIImage(systemName: option.sfSymbolName)
      ) { [weak self] _ in
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        self?.onAddEntryTypeSelected(option.rawValue)
      }
      if #available(iOS 15.0, *) {
        action.subtitle = option.subtitle
      }
      return action
    }
    return UIMenu(title: "", children: actions)
  }

  func presentAddMenu() {
    addButton.sendActions(for: .touchUpInside)
  }

  @objc private func addMenuUnsupported() {
    onAddEntryTypeSelected(NativeAddEntryOption.owedToMe.rawValue)
  }

  func setSelectedTab(_ index: Int) {
    guard let items = tabBar.items, items.indices.contains(index) else { return }
    tabBar.selectedItem = items[index]
  }

  func setNavigationVisible(_ visible: Bool) {
    wantsVisible = visible
    updateVisibility(animated: true)
  }


  private func observeKeyboard() {
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
  }

  @objc private func keyboardWillShow() {
    keyboardVisible = true
    updateVisibility(animated: true)
  }

  @objc private func keyboardWillHide() {
    keyboardVisible = false
    updateVisibility(animated: true)
  }

  private func updateVisibility(animated: Bool) {
    let visible = wantsVisible && (!keyboardVisible || searchState != .normal)
    // This is a full-screen overlay. Keep its container enabled so the
    // point-inside guard can pass taps through when the navigation row is
    // hidden; disabling the container can leave the underlying shell in a
    // stale interaction state after a transition.
    isUserInteractionEnabled = true
    let changes = {
      self.alpha = visible ? 1 : 0
      self.isHidden = !visible
      self.rowContainer.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: 18)
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      changes()
      return
    }
    UIView.animate(withDuration: 0.2, animations: changes)
  }
}
