import UIKit

final class NativeFloatingNavigationView: UIView, UITabBarDelegate {
  private let onTabSelected: (Int) -> Void
  private let onAddEntry: () -> Void
  private let tabBar = UITabBar()
  private let addButton = UIButton(type: .system)
  private let rowContainer = UIView()
  private var wantsVisible = false
  private var keyboardVisible = false

  init(onTabSelected: @escaping (Int) -> Void, onAddEntry: @escaping () -> Void) {
    self.onTabSelected = onTabSelected
    self.onAddEntry = onAddEntry
    super.init(frame: .zero)
    isUserInteractionEnabled = false
    isHidden = true
    alpha = 0
    backgroundColor = .clear
    setupViews()
    observeKeyboard()
    updateVisibility(animated: false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    guard wantsVisible && !keyboardVisible && !isHidden else { return false }
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
    let scratchItem = UITabBarItem(title: "Notes", image: UIImage(systemName: "note.text"), tag: 3)
    scratchItem.accessibilityLabel = "Scratchpad"
    let searchItem = UITabBarItem(title: "Search", image: UIImage(systemName: "magnifyingglass"), tag: 4)
    searchItem.accessibilityLabel = "Search"
    let items = [dashItem, owedToMeItem, owedByMeItem, scratchItem, searchItem]
    tabBar.items = items
    tabBar.selectedItem = items.first

    addButton.translatesAutoresizingMaskIntoConstraints = false
    addButton.accessibilityLabel = "Add entry"
    addButton.accessibilityHint = "Opens the new entry menu"
    addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)

    let plusConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    if #available(iOS 26.0, *) {
      var config = UIButton.Configuration.clearGlass()
      config.image = UIImage(systemName: "plus", withConfiguration: plusConfig)
      config.baseForegroundColor = .label
      addButton.configuration = config
    } else if #available(iOS 15.0, *) {
      var config = UIButton.Configuration.tinted()
      config.image = UIImage(systemName: "plus", withConfiguration: plusConfig)
      config.cornerStyle = .capsule
      config.baseForegroundColor = .label
      addButton.configuration = config
    } else {
      addButton.setImage(UIImage(systemName: "plus", withConfiguration: plusConfig), for: .normal)
      addButton.tintColor = .label
      addButton.layer.cornerRadius = 26
    }

    rowContainer.translatesAutoresizingMaskIntoConstraints = false
    rowContainer.backgroundColor = .clear
    rowContainer.addSubview(tabBar)
    rowContainer.addSubview(addButton)
    addSubview(rowContainer)
    NSLayoutConstraint.activate([
      rowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      rowContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      rowContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 10),
      tabBar.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
      tabBar.topAnchor.constraint(equalTo: rowContainer.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),
      addButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
      addButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
      addButton.widthAnchor.constraint(equalToConstant: 52),
      addButton.heightAnchor.constraint(equalToConstant: 52),
    ])
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    UISelectionFeedbackGenerator().selectionChanged()
    onTabSelected(item.tag)
  }

  @objc private func addTapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    onAddEntry()
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
    let visible = wantsVisible && !keyboardVisible
    isUserInteractionEnabled = visible
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
