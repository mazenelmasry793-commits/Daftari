import UIKit

final class NativeEntryFormViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
  private let entryType: NativeEntryFormType
  private let initialValues: NativeEntryFormInitialValues?
  private let onSubmit: (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void
  private let onDismiss: () -> Void
  var onKeyboardVisibilityChanged: ((Bool) -> Void)?
  private let titleField = UITextField()
  private let amountField = UITextField()
  private let noteView = UITextView()
  private let datePicker = UIDatePicker()
  private let saveButton = UIButton(type: .system)
  private let scrollView = UIScrollView()
  private let contentStack = UIStackView()
  private let notePlaceholder = UILabel()
  private var keyboardObserverTokens: [NSObjectProtocol] = []
  private var isSubmitting = false

  init(
    entryType: NativeEntryFormType,
    initialValues: NativeEntryFormInitialValues? = nil,
    onSubmit: @escaping (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.entryType = entryType
    self.initialValues = initialValues
    self.onSubmit = onSubmit
    self.onDismiss = onDismiss
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    navigationItem.title = initialValues == nil ? "New \(entryType.title)" : "Edit \(entryType.title)"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closeTapped)
    )
    setupForm()
    observeKeyboard()
    updateSaveButton()
  }

  deinit {
    keyboardObserverTokens.forEach(NotificationCenter.default.removeObserver)
  }

  private func setupForm() {
    let effectView: UIVisualEffectView
    if #available(iOS 26.0, *) {
      effectView = UIVisualEffectView(effect: UIGlassEffect())
    } else {
      effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }
    effectView.translatesAutoresizingMaskIntoConstraints = false
    effectView.backgroundColor = .clear
    view.addSubview(effectView)

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentStack.axis = .vertical
    contentStack.spacing = 10
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    effectView.contentView.addSubview(scrollView)
    scrollView.addSubview(contentStack)

    configureTextField(titleField, placeholder: "Who owes what?", keyboardType: .default)
    titleField.text = initialValues?.title
    titleField.returnKeyType = .next
    titleField.delegate = self
    contentStack.addArrangedSubview(fieldContainer(label: "Title", field: titleField))

    configureTextField(amountField, placeholder: "0.00", keyboardType: .decimalPad)
    if let amount = initialValues?.amount { amountField.text = String(amount) }
    amountField.delegate = self
    contentStack.addArrangedSubview(fieldContainer(label: entryType.amountPlaceholder, field: amountField))

    contentStack.addArrangedSubview(formLabel("Date"))
    datePicker.datePickerMode = .date
    datePicker.date = initialValues?.debtDate ?? Date()
    datePicker.minimumDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))
    datePicker.maximumDate = Calendar.current.date(from: DateComponents(year: 2100, month: 12, day: 31))
    if #available(iOS 13.4, *) {
      datePicker.preferredDatePickerStyle = .compact
    }
    datePicker.translatesAutoresizingMaskIntoConstraints = false
    datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
    contentStack.addArrangedSubview(datePicker)

    let noteLabel = formLabel("Note")
    contentStack.addArrangedSubview(noteLabel)
    noteView.font = .preferredFont(forTextStyle: .body)
    applyMinimalSurfaceStyle(to: noteView, cornerRadius: 12)
    noteView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
    noteView.textContainer.lineFragmentPadding = 0
    noteView.delegate = self
    noteView.text = initialValues?.note ?? ""
    notePlaceholder.isHidden = !noteView.text.isEmpty
    noteView.heightAnchor.constraint(equalToConstant: 96).isActive = true
    noteView.addSubview(notePlaceholder)
    notePlaceholder.text = "Add a reminder, explanation, or rough calculation."
    notePlaceholder.textColor = .secondaryLabel
    notePlaceholder.font = .preferredFont(forTextStyle: .body)
    notePlaceholder.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      notePlaceholder.topAnchor.constraint(equalTo: noteView.topAnchor, constant: 10),
      notePlaceholder.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: 10),
      notePlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: noteView.trailingAnchor, constant: -10),
    ])
    contentStack.addArrangedSubview(noteView)

    if #available(iOS 15.0, *) {
      var configuration = UIButton.Configuration.filled()
      configuration.title = "Save"
      configuration.cornerStyle = .medium
      configuration.baseBackgroundColor = .black
      configuration.baseForegroundColor = .white
      configuration.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 20, bottom: 13, trailing: 20)
      saveButton.configuration = configuration
    } else {
      saveButton.setTitle("Save", for: .normal)
      saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
      saveButton.setTitleColor(.white, for: .normal)
      saveButton.backgroundColor = .black
      saveButton.layer.cornerRadius = 8
      saveButton.contentEdgeInsets = UIEdgeInsets(top: 13, left: 20, bottom: 13, right: 20)
    }
    saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    contentStack.addArrangedSubview(saveButton)

    NSLayoutConstraint.activate([
      effectView.topAnchor.constraint(equalTo: view.topAnchor),
      effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scrollView.topAnchor.constraint(equalTo: effectView.contentView.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: effectView.contentView.safeAreaLayoutGuide.bottomAnchor),
      contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
    ])
  }

  private func configureTextField(_ field: UITextField, placeholder: String, keyboardType: UIKeyboardType) {
    field.placeholder = placeholder
    field.font = .preferredFont(forTextStyle: .body)
    field.borderStyle = .none
    applyMinimalSurfaceStyle(to: field, cornerRadius: 12)
    field.keyboardType = keyboardType
    field.clearButtonMode = .whileEditing
    let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
    field.leftView = paddingView
    field.leftViewMode = .always
    field.addTarget(self, action: #selector(textChanged), for: .editingChanged)
    field.heightAnchor.constraint(equalToConstant: 52).isActive = true
  }

  private func applyMinimalSurfaceStyle(to view: UIView, cornerRadius: CGFloat) {
    view.backgroundColor = .clear
    view.layer.cornerRadius = cornerRadius
    view.layer.borderWidth = 0.5
    view.layer.borderColor = UIColor.separator.cgColor
    view.layer.masksToBounds = true
  }

  private func fieldContainer(label: String, field: UITextField) -> UIView {
    let stack = UIStackView(arrangedSubviews: [formLabel(label), field])
    stack.axis = .vertical
    stack.spacing = 6
    return stack
  }

  private func formLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .preferredFont(forTextStyle: .headline)
    return label
  }

  @objc private func textChanged() {
    updateSaveButton()
  }

  @objc private func dateChanged() {
    updateSaveButton()
  }

  func textViewDidChange(_ textView: UITextView) {
    notePlaceholder.isHidden = !textView.text.isEmpty
  }

  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    if textField === titleField {
      amountField.becomeFirstResponder()
    }
    return true
  }

  private func parsedAmount() -> Double? {
    let value = amountField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !value.isEmpty else { return nil }
    return Double(value.replacingOccurrences(of: ",", with: "."))
  }

  private func isValid() -> Bool {
    guard !(titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty else { return false }
    let amount = parsedAmount()
    if entryType != .scratchpad && (amount == nil || amount ?? 0 <= 0) { return false }
    if let paidAmount = initialValues?.paidAmount,
       entryType != .scratchpad,
       let amount,
       amount < paidAmount { return false }
    return amount == nil || amount ?? 0 > 0
  }

  private func updateSaveButton() {
    let enabled = isValid() && !isSubmitting
    saveButton.isEnabled = enabled
    saveButton.alpha = enabled ? 1 : 0.5
  }

  @objc private func closeTapped() {
    view.endEditing(true)
    dismiss(animated: true, completion: onDismiss)
  }

  @objc private func saveTapped() {
    guard isValid(), !isSubmitting else { return }
    isSubmitting = true
    updateSaveButton()
    let payload = NativeEntryFormPayload(
      type: entryType,
      id: initialValues?.id,
      title: titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
      amount: parsedAmount(),
      note: noteView.text.trimmingCharacters(in: .whitespacesAndNewlines),
      debtDate: datePicker.date
    )
    onSubmit(payload) { [weak self] didSave in
      guard let self else { return }
      self.isSubmitting = false
      if didSave {
        self.dismiss(animated: true)
      } else {
        self.updateSaveButton()
      }
    }
  }

  private func observeKeyboard() {
    let center = NotificationCenter.default
    keyboardObserverTokens = [
      center.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { [weak self] notification in
        self?.onKeyboardVisibilityChanged?(true)
        guard let self,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
          return
        }
        let keyboardFrame = self.view.convert(frame, from: nil)
        let overlap = max(0, self.view.bounds.maxY - keyboardFrame.minY - self.view.safeAreaInsets.bottom)
        self.scrollView.contentInset.bottom = overlap + 24
        self.scrollView.verticalScrollIndicatorInsets.bottom = overlap + 24
      },
      center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] _ in
        self?.onKeyboardVisibilityChanged?(false)
        self?.scrollView.contentInset.bottom = 0
        self?.scrollView.verticalScrollIndicatorInsets.bottom = 0
      },
    ]
  }
}
