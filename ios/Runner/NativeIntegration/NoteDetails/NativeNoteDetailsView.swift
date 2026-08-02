import SwiftUI

@available(iOS 26.0, *)
struct NativeNoteDetailsView: View {
  let bridge: NativeNoteDetailsBridge
  @ObservedObject private var store: NativeNoteDetailsStore
  let onBack: () -> Void
  let onDelete: (String) -> Void
  @State private var editSheetPresented = false

  init(
    bridge: NativeNoteDetailsBridge,
    onBack: @escaping () -> Void,
    onDelete: @escaping (String) -> Void
  ) {
    self.bridge = bridge
    self.onBack = onBack
    self.onDelete = onDelete
    _store = ObservedObject(wrappedValue: bridge.store)
  }

  var body: some View {
    NavigationStack {
      Group {
        if let snapshot = store.snapshot {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              Text(snapshot.note.isEmpty ? "No note added" : snapshot.note)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
          }
        } else if store.isLoading {
          ProgressView()
        } else {
          ContentUnavailableView("Note not found", systemImage: "note.text")
        }
      }
      .background(Color(uiColor: .systemBackground))
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: onBack) { Image(systemName: "chevron.left") }
            .accessibilityLabel("Back")
        }
        ToolbarItem(placement: .principal) {
          if let snapshot = store.snapshot {
            VStack(spacing: 1) {
              Text(snapshot.title).font(.headline).lineLimit(1)
              HStack(spacing: 5) {
                Image(systemName: "calendar")
                Text(snapshot.dateText)
              }
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityElement(children: .combine)
              .accessibilityLabel(snapshot.dateText)
            }
          }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          if let snapshot = store.snapshot {
            Button {
              editSheetPresented = true
            } label: {
              Label("Edit", systemImage: "pencil")
                .labelStyle(.iconOnly)
            }
            .accessibilityLabel("Edit")

            Button(role: .destructive) {
              onDelete(snapshot.id)
            } label: {
              Label("Delete", systemImage: "trash")
                .labelStyle(.iconOnly)
            }
            .tint(.red)
            .accessibilityLabel("Delete")
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
    }
    .sheet(isPresented: $editSheetPresented) {
      if let snapshot = store.snapshot {
        NativeNoteDetailsEditSheet(
          snapshot: snapshot,
          onSave: { input, completion in
            bridge.perform(action: .save, id: snapshot.id, input: input) { success in
              completion(success)
            }
          }
        )
      }
    }
  }

}

@available(iOS 26.0, *)
private struct NativeNoteDetailsEditSheet: View {
  @Environment(\.dismiss) private var dismiss
  let snapshot: NativeNoteDetailsSnapshot
  let onSave: (NativeNoteDetailsInput, @escaping (Bool) -> Void) -> Void
  @State private var title: String
  @State private var note: String
  @State private var date: Date
  @State private var saving = false
  @State private var showDiscardAlert = false
  @FocusState private var focusedField: Field?

  private enum Field {
    case title
    case note
  }

  init(
    snapshot: NativeNoteDetailsSnapshot,
    onSave: @escaping (NativeNoteDetailsInput, @escaping (Bool) -> Void) -> Void
  ) {
    self.snapshot = snapshot
    self.onSave = onSave
    _title = State(initialValue: snapshot.title)
    _note = State(initialValue: snapshot.note)
    _date = State(initialValue: snapshot.date ?? Date())
  }

  private var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  private var changed: Bool {
    title != snapshot.title || note != snapshot.note ||
      snapshot.date.map { abs(date.timeIntervalSince($0)) > 0.5 } != false
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Title", text: $title)
            .focused($focusedField, equals: .title)
          TextEditor(text: $note)
            .focused($focusedField, equals: .note)
            .frame(height: 140)
          DatePicker("Date", selection: $date, displayedComponents: .date)
            .datePickerStyle(.compact)
        }
      }
      .scrollContentBackground(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .navigationTitle("Edit Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { cancel() }.disabled(saving)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saving = true
            onSave(
              NativeNoteDetailsInput(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                note: note,
                date: date
              )
            ) { success in
              saving = false
              if success { dismiss() }
            }
          }
          .disabled(!valid || saving)
        }
      }
      .alert("Discard changes?", isPresented: $showDiscardAlert) {
        Button("Keep Editing", role: .cancel) {}
        Button("Discard", role: .destructive) { dismiss() }
      }
    }
    .interactiveDismissDisabled(changed || saving)
    .presentationDetents([.height(470)])
    .presentationContentInteraction(.scrolls)
    .presentationDragIndicator(.visible)
    .presentationCornerRadius(32)
  }

  private func cancel() {
    if changed { showDiscardAlert = true } else { dismiss() }
  }
}
