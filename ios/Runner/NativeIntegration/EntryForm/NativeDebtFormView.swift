import SwiftUI

@available(iOS 16.4, *)
struct NativeDebtFormView: View {
  let initialValues: NativeEntryFormInitialValues?
  let entryType: NativeEntryFormType
  let onSubmit: (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var amount: String
  @State private var note: String
  @State private var date: Date
  @State private var isSubmitting = false

  init(
    entryType: NativeEntryFormType,
    initialValues: NativeEntryFormInitialValues?,
    onSubmit: @escaping (NativeEntryFormPayload, @escaping (Bool) -> Void) -> Void
  ) {
    self.entryType = entryType
    self.initialValues = initialValues
    self.onSubmit = onSubmit
    _title = State(initialValue: initialValues?.title ?? "")
    _amount = State(initialValue: initialValues?.amount.map { String($0) } ?? "")
    _note = State(initialValue: initialValues?.note ?? "")
    _date = State(initialValue: initialValues?.debtDate ?? Date())
  }

  private var parsedAmount: Double? {
    Double(amount.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: ",", with: "."))
  }

  private var isValid: Bool {
    guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let parsedAmount,
          parsedAmount > 0 else { return false }
    if let paidAmount = initialValues?.paidAmount, parsedAmount < paidAmount {
      return false
    }
    return true
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          compactField(title: "Title", placeholder: titlePlaceholder, text: $title)
          compactField(title: "Amount", placeholder: "0.00", text: $amount)
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
      .navigationTitle(initialValues == nil ? "New \(entryType.title)" : "Edit \(entryType.title)")
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

  private var titlePlaceholder: String {
    entryType == .owedByMe ? "Who do I owe?" : "Who owes what?"
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
    guard isValid, !isSubmitting, let parsedAmount else { return }
    isSubmitting = true
    let payload = NativeEntryFormPayload(
      type: entryType,
      id: initialValues?.id,
      title: title.trimmingCharacters(in: .whitespacesAndNewlines),
      amount: parsedAmount,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      debtDate: date
    )
    onSubmit(payload) { success in
      if success {
        dismiss()
      } else {
        isSubmitting = false
      }
    }
  }
}
