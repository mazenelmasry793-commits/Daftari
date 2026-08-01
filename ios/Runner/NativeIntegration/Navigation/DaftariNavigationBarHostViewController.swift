import UIKit

@available(iOS 26.0, *)
final class DaftariNavigationBarHostViewController: UIViewController {
  private let headerViewController: UIViewController
  private let embeddedNavigationController: UINavigationController
  private let addItem: UIBarButtonItem
  private let settingsItem: UIBarButtonItem
  private let onSettingsRequested: () -> Void
  private let onAddEntryTypeSelected: (String) -> Void
  private var isVisible = false

  init(
    onSettingsRequested: @escaping () -> Void,
    onAddEntryTypeSelected: @escaping (String) -> Void
  ) {
    self.onSettingsRequested = onSettingsRequested
    self.onAddEntryTypeSelected = onAddEntryTypeSelected
    let header = UIViewController()
    self.headerViewController = header
    self.embeddedNavigationController = UINavigationController(rootViewController: header)

    let addImage = UIImage(
      systemName: "plus",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    )
    let settingsImage = UIImage(
      systemName: "gearshape.fill",
      withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    )
    self.addItem = UIBarButtonItem(image: addImage, style: .plain, target: nil, action: nil)
    self.settingsItem = UIBarButtonItem(image: settingsImage, style: .plain, target: nil, action: nil)
    super.init(nibName: nil, bundle: nil)

    headerViewController.navigationItem.rightBarButtonItems = [settingsItem, addItem]
    addItem.accessibilityLabel = "Add entry"
    addItem.accessibilityHint = "Opens the new entry menu"
    addItem.menu = makeAddMenu()
    settingsItem.accessibilityLabel = "Settings"
    settingsItem.target = self
    settingsItem.action = #selector(settingsTapped)
    embeddedNavigationController.setNavigationBarHidden(false, animated: false)
    embeddedNavigationController.view.backgroundColor = .clear
    embeddedNavigationController.navigationBar.backgroundColor = .clear
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isOpaque = false
    addChild(embeddedNavigationController)
    view.addSubview(embeddedNavigationController.view)
    embeddedNavigationController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      embeddedNavigationController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      embeddedNavigationController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      embeddedNavigationController.view.topAnchor.constraint(equalTo: view.topAnchor),
      embeddedNavigationController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    embeddedNavigationController.didMove(toParent: self)
    setVisible(false, animated: false)
  }

  func setVisible(_ visible: Bool, animated: Bool) {
    isVisible = visible
    let update = {
      self.view.isHidden = !visible
      self.headerViewController.navigationItem.rightBarButtonItems = visible
        ? [self.settingsItem, self.addItem]
        : nil
      self.embeddedNavigationController.setNavigationBarHidden(!visible, animated: false)
      self.embeddedNavigationController.navigationBar.isUserInteractionEnabled = visible
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      update()
      return
    }
    UIView.animate(withDuration: 0.2, animations: update)
  }

  func presentAddMenu() {
    addItem.menu = makeAddMenu()
  }

  private func makeAddMenu() -> UIMenu {
    UIMenu(
      title: "",
      children: NativeAddEntryOption.allCases.map { option in
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
    )
  }

  @objc private func settingsTapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    onSettingsRequested()
  }
}
