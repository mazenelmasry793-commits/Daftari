import UIKit

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
    cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    let doneButton = UIButton(type: .system)
    doneButton.setTitle("Done", for: .normal)
    doneButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
    doneButton.translatesAutoresizingMaskIntoConstraints = false
    doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
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
      datePicker.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
    ])
  }

  @objc private func cancelTapped() {
    dismiss(animated: true) { [weak self] in self?.onSelect(nil) }
  }

  @objc private func doneTapped() {
    let selectedDate = datePicker.date
    dismiss(animated: true) { [weak self] in self?.onSelect(selectedDate) }
  }
}
