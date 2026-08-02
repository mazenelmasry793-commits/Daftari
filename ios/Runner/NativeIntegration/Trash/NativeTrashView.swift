import SwiftUI

@available(iOS 26.0, *)
struct NativeTrashView: View {
  @ObservedObject var store: NativeTrashStore
  let onBack: () -> Void
  let onEntrySelected: (String) -> Void
  let onRestore: (String) -> Void
  let onDeleteForever: (String) -> Void
  let onEmptyTrash: () -> Void

  var body: some View {
    NavigationStack {
      Group {
        if store.entries.isEmpty {
          ContentUnavailableView(
            "Trash is Empty",
            systemImage: "trash",
            description: Text(
              "Deleted entries will appear here until you restore or delete them forever."
            )
          )
          .offset(y: -24)
        } else {
          List {
            ForEach(store.entries) { entry in
              Button { onEntrySelected(entry.id) } label: {
                trashRow(entry)
              }
              .buttonStyle(.plain)
              .disabled(store.actionInFlight)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                  onRestore(entry.id)
                } label: {
                  Label("Restore", systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)

                Button(role: .destructive) {
                  onDeleteForever(entry.id)
                } label: {
                  Label("Delete Forever", systemImage: "trash")
                }
              }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Trash")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: onBack) {
            Label("Back", systemImage: "chevron.left")
              .labelStyle(.iconOnly)
          }
          .accessibilityLabel("Back")
        }
        if !store.entries.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Empty Trash", role: .destructive, action: onEmptyTrash)
          }
        }
      }
    }
  }

  private func trashRow(_ entry: NativeTrashEntry) -> some View {
    HStack(spacing: 12) {
      Image(systemName: entry.symbolName)
        .font(.body.weight(.semibold))
        .foregroundStyle(.secondary)
        .frame(width: 42, height: 42)
        .background(.secondary.opacity(0.12), in: Circle())

      VStack(alignment: .leading, spacing: 3) {
        Text(entry.title)
          .font(.body.weight(.semibold))
          .lineLimit(1)
        Text(entry.typeText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HStack(spacing: 5) {
          Image(systemName: "calendar")
          Text(entry.dateText)
          if let amountText = entry.amountText {
            Text("·")
            Text(amountText)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer(minLength: 8)
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
    .padding(.vertical, 5)
  }
}
