import UIKit

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
