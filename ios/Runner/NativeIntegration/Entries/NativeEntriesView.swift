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
        if type == .owedToMe {
          owedToMeContent
        } else {
          genericContent
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

  @ViewBuilder
  private var genericContent: some View {
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

  @ViewBuilder
  private var owedToMeContent: some View {
    if filteredEntries.isEmpty {
      ContentUnavailableView {
        Label("No money owed to you", systemImage: "arrow.down.left.circle")
      } description: {
        Text("New amounts owed to you will appear here.")
      } actions: {
        Button("Add Entry", action: onAdd)
          .buttonStyle(.borderedProminent)
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          OwedToMeSummaryCard(
            totalText: store.owedToMeTotalText,
            entryCount: store.owedToMeEntryCount
          )
          Text("People")
            .font(.title3.weight(.semibold))
            .padding(.top, 4)
          OwedToMeGroupedList(
            entries: filteredEntries,
            onEntrySelected: onEntrySelected
          )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 96)
      }
      .scrollIndicators(.hidden)
    }
  }
}

@available(iOS 26.0, *)
private struct OwedToMeSummaryCard: View {
  let totalText: String
  let entryCount: Int

  private var countText: String {
    "\(entryCount) active \(entryCount == 1 ? "entry" : "entries")"
  }

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "arrow.down.left")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.blue)
        .frame(width: 42, height: 42)
        .background(.white.opacity(0.7), in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text("Total Owed")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
        Text(countText)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 8)
      Text(totalText)
        .font(.system(.title3, design: .rounded).weight(.bold))
        .foregroundStyle(.blue)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
        .layoutPriority(1)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 96)
    .background(
      LinearGradient(
        colors: [Color.blue.opacity(0.12), Color.blue.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 22, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.blue.opacity(0.12), lineWidth: 1)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Total owed \(totalText), \(countText)")
  }
}

@available(iOS 26.0, *)
private struct OwedToMeGroupedList: View {
  let entries: [NativeEntryListItem]
  let onEntrySelected: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
        Button { onEntrySelected(entry.id) } label: {
          OwedToMeEntryRow(entry: entry)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.title), \(entry.amountText), \(entry.dateText)")
        if index < entries.count - 1 {
          Divider().padding(.leading, 82)
        }
      }
    }
    .padding(.vertical, 4)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    }
  }
}

@available(iOS 26.0, *)
private struct OwedToMeEntryRow: View {
  let entry: NativeEntryListItem

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "arrow.down.left")
        .font(.title3.weight(.semibold))
        .foregroundStyle(.blue)
        .frame(width: 54, height: 54)
        .background(Color.blue.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title)
          .font(.headline.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.tail)
        Text(entry.dateText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(entry.amountText)
        .font(.headline.weight(.semibold))
        .foregroundStyle(.blue)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 14)
    .frame(minHeight: 86)
    .contentShape(Rectangle())
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
