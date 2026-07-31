import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var navigationOverlay: NativeFloatingNavigationView?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    DispatchQueue.main.async { [weak self] in self?.installNativeNavigation() }
  }

  private func installNativeNavigation() {
    guard navigationOverlay == nil,
          let flutterViewController = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.daftari/native_bottom_navigation",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    let overlay = NativeFloatingNavigationView(channel: channel)
    flutterViewController.view.addSubview(overlay)
    overlay.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      overlay.leadingAnchor.constraint(equalTo: flutterViewController.view.leadingAnchor),
      overlay.trailingAnchor.constraint(equalTo: flutterViewController.view.trailingAnchor),
      overlay.bottomAnchor.constraint(equalTo: flutterViewController.view.bottomAnchor),
      overlay.topAnchor.constraint(equalTo: flutterViewController.view.topAnchor),
    ])
    navigationOverlay = overlay

    NativeSheetCoordinator.shared.configure(messenger: flutterViewController.binaryMessenger)

    channel.setMethodCallHandler { [weak overlay] call, result in
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "setSelectedTab":
        overlay?.setSelectedTab(arguments?["index"] as? Int ?? 0)
        result(nil)
      case "setNavigationVisible":
        overlay?.setNavigationVisible(arguments?["visible"] as? Bool ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class NativeFloatingNavigationView: UIView, UITabBarDelegate {
  private let channel: FlutterMethodChannel
  private let tabBar = UITabBar()
  private let addButton = UIButton(type: .system)
  private let rowContainer = UIView()
  private var wantsVisible = false
  private var keyboardVisible = false

  init(channel: FlutterMethodChannel) {
    self.channel = channel
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

    // Use a row container to keep tabBar and addButton on the same row, vertically centered
    rowContainer.translatesAutoresizingMaskIntoConstraints = false
    rowContainer.backgroundColor = .clear
    rowContainer.addSubview(tabBar)
    rowContainer.addSubview(addButton)
    addSubview(rowContainer)

    NSLayoutConstraint.activate([
      // Row container spans full width, pinned to bottom safe area
      rowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      rowContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
      rowContainer.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: 10),

      // TabBar fills left side of row container
      tabBar.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -8),
      tabBar.topAnchor.constraint(equalTo: rowContainer.topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: rowContainer.bottomAnchor),

      // Add button on the right, vertically centered to the row container
      addButton.trailingAnchor.constraint(equalTo: rowContainer.trailingAnchor),
      addButton.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
      addButton.widthAnchor.constraint(equalToConstant: 52),
      addButton.heightAnchor.constraint(equalToConstant: 52),
    ])
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    print("DEBUG_FRAME root: \(bounds)")
    print("DEBUG_FRAME tabBar: \(tabBar.frame)")
    print("DEBUG_FRAME addButton: \(addButton.frame)")
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    UISelectionFeedbackGenerator().selectionChanged()
    channel.invokeMethod("nativeTabSelected", arguments: ["index": item.tag])
  }

  @objc private func addTapped() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
      NativeSheetCoordinator.shared.presentAddEntryChooser(from: rootVC)
    } else {
      channel.invokeMethod("openAddEntry", arguments: nil)
    }
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
      let transform = visible ? CGAffineTransform.identity : CGAffineTransform(translationX: 0, y: 18)
      self.rowContainer.transform = transform
    }
    guard animated, !UIAccessibility.isReduceMotionEnabled else {
      changes()
      return
    }
    UIView.animate(withDuration: 0.2, animations: changes)
  }
}

enum NativeAddEntryOption: String, CaseIterable {
  case owedToMe = "owedToMe"
  case owedByMe = "owedByMe"
  case scratchpad = "scratchpad"

  var title: String {
    switch self {
    case .owedToMe: return "Owed To Me"
    case .owedByMe: return "Owed By Me"
    case .scratchpad: return "Scratchpad"
    }
  }

  var subtitle: String {
    switch self {
    case .owedToMe: return "Track money someone owes you."
    case .owedByMe: return "Track money you owe someone."
    case .scratchpad: return "Quick note or rough calculation."
    }
  }

  var sfSymbolName: String {
    switch self {
    case .owedToMe: return "arrow.down.left"
    case .owedByMe: return "arrow.up.right"
    case .scratchpad: return "note.text"
    }
  }

  var accessibilityHint: String {
    switch self {
    case .owedToMe: return "Creates a debt someone owes you."
    case .owedByMe: return "Creates a debt you owe someone."
    case .scratchpad: return "Creates a quick note or calculation."
    }
  }
}

final class NativeAddEntrySheetViewController: UIViewController {
  private let onSelect: (NativeAddEntryOption) -> Void

  init(onSelect: @escaping (NativeAddEntryOption) -> Void) {
    self.onSelect = onSelect
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupContent()
  }

  private func setupContent() {
    let stackView = UIStackView()
    stackView.axis = .vertical
    stackView.spacing = 8
    stackView.distribution = .fillEqually
    stackView.translatesAutoresizingMaskIntoConstraints = false

    for option in NativeAddEntryOption.allCases {
      let rowControl = createRowControl(for: option)
      stackView.addArrangedSubview(rowControl)
    }

    view.addSubview(stackView)

    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
      stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
    ])
  }

  private func createRowControl(for option: NativeAddEntryOption) -> UIControl {
    let control = UIControl()
    control.translatesAutoresizingMaskIntoConstraints = false

    let iconImageView = UIImageView()
    let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    iconImageView.image = UIImage(systemName: option.sfSymbolName, withConfiguration: symbolConfig)
    iconImageView.tintColor = .label
    iconImageView.contentMode = .scaleAspectFit
    iconImageView.translatesAutoresizingMaskIntoConstraints = false
    iconImageView.setContentHuggingPriority(.required, for: .horizontal)

    let textStack = UIStackView()
    textStack.axis = .vertical
    textStack.spacing = 3
    textStack.alignment = .leading
    textStack.isUserInteractionEnabled = false
    textStack.translatesAutoresizingMaskIntoConstraints = false

    let titleLabel = UILabel()
    titleLabel.text = option.title
    titleLabel.font = .preferredFont(forTextStyle: .headline)
    titleLabel.textColor = .label

    let subtitleLabel = UILabel()
    subtitleLabel.text = option.subtitle
    subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
    subtitleLabel.textColor = .secondaryLabel
    subtitleLabel.numberOfLines = 1

    textStack.addArrangedSubview(titleLabel)
    textStack.addArrangedSubview(subtitleLabel)

    let mainStack = UIStackView(arrangedSubviews: [iconImageView, textStack])
    mainStack.axis = .horizontal
    mainStack.spacing = 16
    mainStack.alignment = .center
    mainStack.isUserInteractionEnabled = false
    mainStack.translatesAutoresizingMaskIntoConstraints = false

    control.addSubview(mainStack)

    NSLayoutConstraint.activate([
      iconImageView.widthAnchor.constraint(equalToConstant: 28),
      iconImageView.heightAnchor.constraint(equalToConstant: 28),

      mainStack.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 16),
      mainStack.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -16),
      mainStack.centerYAnchor.constraint(equalTo: control.centerYAnchor),
      control.heightAnchor.constraint(equalToConstant: 76)
    ])

    control.accessibilityLabel = option.title
    control.accessibilityHint = option.accessibilityHint

    if #available(iOS 14.0, *) {
      control.addAction(UIAction { [weak self] _ in
        self?.onSelect(option)
      }, for: .touchUpInside)
    }

    return control
  }
}

final class NativeDatePickerViewController: UIViewController {
  private let datePicker = UIDatePicker()
  private let onSelect: (Date?) -> Void
  private let initialDate: Date
  private let minimumDate: Date?
  private let maximumDate: Date?

  init(initialDate: Date, minimumDate: Date?, maximumDate: Date?, onSelect: @escaping (Date?) -> Void) {
    self.initialDate = initialDate
    self.minimumDate = minimumDate
    self.maximumDate = maximumDate
    self.onSelect = onSelect
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupUI()
  }

  private func setupUI() {
    let headerView = UIView()
    headerView.translatesAutoresizingMaskIntoConstraints = false

    let cancelButton = UIButton(type: .system)
    cancelButton.setTitle("Cancel", for: .normal)
    cancelButton.titleLabel?.font = .preferredFont(forTextStyle: .body)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 14.0, *) {
      cancelButton.addAction(UIAction { [weak self] _ in
        self?.cancelTapped()
      }, for: .touchUpInside)
    }

    let doneButton = UIButton(type: .system)
    doneButton.setTitle("Done", for: .normal)
    doneButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
    doneButton.translatesAutoresizingMaskIntoConstraints = false
    if #available(iOS 14.0, *) {
      doneButton.addAction(UIAction { [weak self] _ in
        self?.doneTapped()
      }, for: .touchUpInside)
    }

    let titleLabel = UILabel()
    titleLabel.text = "Select Date"
    titleLabel.font = .boldSystemFont(ofSize: 17)
    titleLabel.textColor = .label
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    headerView.addSubview(cancelButton)
    headerView.addSubview(titleLabel)
    headerView.addSubview(doneButton)

    datePicker.datePickerMode = .date
    datePicker.date = initialDate
    datePicker.minimumDate = minimumDate
    datePicker.maximumDate = maximumDate
    if #available(iOS 14.0, *) {
      datePicker.preferredDatePickerStyle = .inline
    } else if #available(iOS 13.4, *) {
      datePicker.preferredDatePickerStyle = .wheels
    }
    datePicker.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(headerView)
    view.addSubview(datePicker)

    NSLayoutConstraint.activate([
      headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
      headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      headerView.heightAnchor.constraint(equalToConstant: 44),

      cancelButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
      cancelButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

      titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

      doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
      doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

      datePicker.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
      datePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      datePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      datePicker.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
    ])
  }

  private func cancelTapped() {
    dismiss(animated: true) { [weak self] in
      self?.onSelect(nil)
    }
  }

  private func doneTapped() {
    let selectedDate = datePicker.date
    dismiss(animated: true) { [weak self] in
      self?.onSelect(selectedDate)
    }
  }
}

final class NativeSheetCoordinator: NSObject, UIAdaptivePresentationControllerDelegate {
  static let shared = NativeSheetCoordinator()

  private(set) var isPresented = false
  private var sheetsChannel: FlutterMethodChannel?
  private weak var currentPresenter: UIViewController?

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.daftari/native_sheets", binaryMessenger: messenger)
    self.sheetsChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "showAddEntryChooser":
        if let presenter = self?.findTopViewController() {
          self?.presentAddEntryChooser(from: presenter)
        }
        result(nil)
      case "showNativeDatePicker":
        let args = call.arguments as? [String: Any]
        let initialIso = args?["initialDate"] as? String ?? ""
        let minIso = args?["minimumDate"] as? String
        let maxIso = args?["maximumDate"] as? String

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()

        let initialDate = formatter.date(from: initialIso) ?? fallbackFormatter.date(from: initialIso) ?? Date()
        let minDate = minIso != nil ? (formatter.date(from: minIso!) ?? fallbackFormatter.date(from: minIso!)) : nil
        let maxDate = maxIso != nil ? (formatter.date(from: maxIso!) ?? fallbackFormatter.date(from: maxIso!)) : nil

        if let presenter = self?.findTopViewController() {
          self?.presentNativeDatePicker(from: presenter, initialDate: initialDate, minDate: minDate, maxDate: maxDate) { selectedDate in
            if let selectedDate = selectedDate {
              result(formatter.string(from: selectedDate))
            } else {
              result(nil)
            }
          }
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func presentAddEntryChooser(from presenter: UIViewController) {
    guard !isPresented else { return }
    isPresented = true
    currentPresenter = presenter

    let sheetVC = NativeAddEntrySheetViewController { [weak self] selectedOption in
      self?.dismissAndNotify(selectedOption: selectedOption)
    }

    sheetVC.modalPresentationStyle = .pageSheet
    if #available(iOS 15.0, *) {
      if let sheet = sheetVC.sheetPresentationController {
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 24
        if #available(iOS 16.0, *) {
          sheet.detents = [
            .custom(identifier: .init("addEntryChooser")) { context in
              min(350, context.maximumDetentValue)
            }
          ]
        } else {
          sheet.detents = [.medium()]
        }
      }
    }

    sheetVC.presentationController?.delegate = self
    presenter.present(sheetVC, animated: true)
  }

  func presentNativeDatePicker(from presenter: UIViewController, initialDate: Date, minDate: Date?, maxDate: Date?, completion: @escaping (Date?) -> Void) {
    guard !isPresented else { return }
    isPresented = true

    let pickerVC = NativeDatePickerViewController(initialDate: initialDate, minimumDate: minDate, maximumDate: maxDate) { [weak self] selectedDate in
      self?.isPresented = false
      completion(selectedDate)
    }

    pickerVC.modalPresentationStyle = .pageSheet
    if #available(iOS 15.0, *) {
      if let sheet = pickerVC.sheetPresentationController {
        sheet.prefersGrabberVisible = true
        sheet.preferredCornerRadius = 24
        if #available(iOS 16.0, *) {
          sheet.detents = [
            .custom(identifier: .init("nativeDatePicker")) { context in
              min(440, context.maximumDetentValue)
            }
          ]
        } else {
          sheet.detents = [.medium()]
        }
      }
    }

    pickerVC.presentationController?.delegate = self
    presenter.present(pickerVC, animated: true)
  }

  private func dismissAndNotify(selectedOption: NativeAddEntryOption) {
    guard let presenter = currentPresenter ?? findTopViewController() else { return }
    presenter.dismiss(animated: true) { [weak self] in
      self?.isPresented = false
      self?.sheetsChannel?.invokeMethod("addEntryTypeSelected", arguments: ["type": selectedOption.rawValue])
    }
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    isPresented = false
    sheetsChannel?.invokeMethod("addEntryChooserDismissed", arguments: nil)
  }

  private func findTopViewController() -> UIViewController? {
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      return nil
    }
    var top = rootVC
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}
