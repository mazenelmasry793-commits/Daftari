import SwiftUI

@available(iOS 26.0, *)
struct NativeSettingsView: View {
  let onBack: () -> Void
  let onTrash: () -> Void
  let onExport: () -> Void
  let onImport: () -> Void
  let onEmptyTrash: () -> Void
  let onDeleteAllData: () -> Void

  @State private var pendingAlert: AlertKind?

  private enum AlertKind: Identifiable {
    case emptyTrash
    case deleteAllData

    var id: String {
      switch self {
      case .emptyTrash: return "empty-trash"
      case .deleteAllData: return "delete-all-data"
      }
    }
  }

  var body: some View {
    NavigationStack {
      List {
        Section("DATA") {
          settingsRow(
            icon: "trash",
            iconColor: .secondary,
            title: "Trash",
            description: "View or restore deleted entries.",
            showsChevron: true,
            action: onTrash
          )
          settingsRow(
            icon: "square.and.arrow.up",
            iconColor: .blue,
            title: "Export JSON",
            description: "Save a backup file on this device.",
            showsChevron: true,
            action: onExport
          )
          settingsRow(
            icon: "square.and.arrow.down",
            iconColor: .green,
            title: "Import JSON",
            description: "Restore entries from a backup file.",
            showsChevron: true,
            action: onImport
          )
        }

        Section("DANGER ZONE") {
          settingsRow(
            icon: "trash",
            iconColor: .red,
            title: "Empty Trash",
            description: "Permanently delete all items in Trash.",
            showsChevron: false,
            titleColor: .red
          ) {
            pendingAlert = .emptyTrash
          }
          settingsRow(
            icon: "trash.slash",
            iconColor: .red,
            title: "Delete All Data",
            description: "Remove every entry from the device.",
            showsChevron: false,
            titleColor: .red
          ) {
            pendingAlert = .deleteAllData
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Color(uiColor: .systemGroupedBackground))
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(action: onBack) {
            Label("Back", systemImage: "chevron.left")
              .labelStyle(.iconOnly)
          }
          .accessibilityLabel("Back")
        }
      }
    }
    .alert(item: $pendingAlert) { alert in
      switch alert {
      case .emptyTrash:
        Alert(
          title: Text("Empty Trash?"),
          message: Text("This permanently deletes all items currently in Trash."),
          primaryButton: .destructive(Text("Empty Trash")) {
            pendingAlert = nil
            onEmptyTrash()
          },
          secondaryButton: .cancel()
        )
      case .deleteAllData:
        Alert(
          title: Text("Delete all data?"),
          message: Text("This permanently removes every entry from this device."),
          primaryButton: .destructive(Text("Delete All Data")) {
            pendingAlert = nil
            onDeleteAllData()
          },
          secondaryButton: .cancel()
        )
      }
    }
  }

  @ViewBuilder
  private func settingsRow(
    icon: String,
    iconColor: Color,
    title: String,
    description: String,
    showsChevron: Bool,
    titleColor: Color = .primary,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .font(.body.weight(.semibold))
          .foregroundStyle(iconColor)
          .frame(width: 42, height: 42)
          .background(iconColor.opacity(0.12), in: Circle())

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(titleColor)
          Text(description)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        Spacer(minLength: 8)
        if showsChevron {
          Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
      }
      .contentShape(Rectangle())
      .padding(.vertical, 5)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
  }
}
