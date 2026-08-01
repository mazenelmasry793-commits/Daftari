import SwiftUI

@available(iOS 26.0, *)
struct NativeEntriesView: View {
  @ObservedObject var store: NativeEntriesStore
  let type: NativeEntryListType
  let onAdd: () -> Void
  let onSettings: () -> Void
  let onEntrySelected: (String) -> Void

  private var filteredEntries: [NativeEntryListItem] { store.entries(for: type) }

  var body: some View {
    NavigationStack {
      Group {
        if filteredEntries.isEmpty {
          ContentUnavailableView {
            Label(type.emptyTitle, systemImage: type.symbolName)
          } description: {
            Text(type.emptyMessage)
          } actions: {
            Button(type == .scratchpad ? "Add Note" : "Add Entry", action: onAdd)
              .buttonStyle(.borderedProminent)
          }
        } else {
          ScrollView {
            LazyVStack(spacing: 12) {
              ForEach(filteredEntries) { entry in
                Button { onEntrySelected(entry.id) } label: {
                  NativeEntryRow(entry: entry, type: type)
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
          }
          .scrollIndicators(.hidden)
        }
      }
      .background(Color(uiColor: .systemBackground))
      .navigationTitle(type.title)
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItemGroup(placement: .topBarTrailing) {
          Button(action: onAdd) { Image(systemName: "plus") }
            .accessibilityLabel(type == .scratchpad ? "Add Note" : "Add Entry")
          Button(action: onSettings) { Image(systemName: "gearshape.fill") }
            .accessibilityLabel("Settings")
        }
      }
    }
  }
}

@available(iOS 26.0, *)
private struct NativeEntryRow: View {
  let entry: NativeEntryListItem
  let type: NativeEntryListType

  private var tint: Color {
    switch type {
    case .owedToMe: return .blue
    case .owedByMe: return .orange
    case .scratchpad: return .indigo
    }
  }

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: entry.symbolName)
        .font(.title3.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 52, height: 52)
        .background(tint.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 5) {
        Text(entry.title).font(.headline).foregroundStyle(.primary)
        Text(entry.dateText).font(.subheadline).foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      VStack(alignment: .trailing, spacing: 5) {
        Text(entry.amountText)
          .font(.headline.weight(.semibold))
          .foregroundStyle(tint)
        Image(systemName: "chevron.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(.tertiary)
      }
    }
    .padding(16)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
  }
}
