import SwiftUI

@available(iOS 16.4, *)
struct NativeScratchpadFormView: View {
  let initialValues: NativeEntryFormInitialValues?
  let onSubmit: (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var amount: String
  @State private var note: String
  @State private var date: Date
  @State private var isSubmitting = false

  init(
    initialValues: NativeEntryFormInitialValues?,
    onSubmit: @escaping (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void
  ) {
    self.initialValues = initialValues
    self.onSubmit = onSubmit
    _title = State(initialValue: initialValues?.title ?? "")
    _amount = State(initialValue: initialValues?.amount.map { String($0) } ?? "")
    _note = State(initialValue: initialValues?.note ?? "")
    _date = State(initialValue: initialValues?.debtDate ?? Date())
  }

  private var parsedAmount: Double? {
    let value = amount.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    return Double(value.replacingOccurrences(of: ",", with: "."))
  }

  private var isValid: Bool {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
    guard let parsedAmount else { return true }
    return parsedAmount > 0
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          compactField(title: "Title", placeholder: "Quick note title", text: $title)
          compactField(title: "Amount (optional)", placeholder: "0.00", text: $amount)
            .keyboardType(.decimalPad)

          Text("Note")
            .font(.headline)
          TextEditor(text: $note)
            .frame(minHeight: 92, maxHeight: 108)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
              RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
            }

          HStack {
            Text("Date")
              .font(.headline)
            Spacer()
            DatePicker("Date", selection: $date, displayedComponents: .date)
              .labelsHidden()
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
      }
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle(initialValues == nil ? "New Scratchpad" : "Edit Scratchpad")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Label("Close", systemImage: "xmark")
              .labelStyle(.iconOnly)
          }
          .accessibilityLabel("Close")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            save()
          }
          .disabled(!isValid || isSubmitting)
        }
      }
    }
    .presentationDetents([.height(520)])
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(28)
  }

  @ViewBuilder
  private func compactField(
    title: String,
    placeholder: String,
    text: Binding<String>
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.headline)
      TextField(placeholder, text: text)
        .textFieldStyle(.plain)
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
        }
    }
  }

  private func save() {
    guard isValid, !isSubmitting else { return }
    isSubmitting = true
    let payload = NativeEntryFormPayload(
      type: .scratchpad,
      id: initialValues?.id,
      title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      amount: parsedAmount,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      debtDate: date
    )
    onSubmit(payload) { success in
      if success { dismiss() }
      else { isSubmitting = false }
    }
  }
}
