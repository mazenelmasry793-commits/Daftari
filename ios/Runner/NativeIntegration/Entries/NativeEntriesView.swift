import SwiftUI

@available(iOS 26.0, *)
struct NativeEntriesView: View {
  @ObservedObject var store: NativeEntriesStore
  let type: NativeEntryListType
  let onAdd: () -> Void
  let onSettings: () -> Void
  let onEntrySelected: (String) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var sortOrder: DateSortOrder = .newestFirst

  private var filteredEntries: [NativeEntryListItem] {
    let entries = store.entries(for: type)
    guard type == .owedToMe else { return entries }

    return entries.enumerated().sorted { lhs, rhs in
      if lhs.element.date != rhs.element.date {
        return sortOrder == .newestFirst
          ? lhs.element.date > rhs.element.date
          : lhs.element.date < rhs.element.date
      }
      // Preserve canonical Flutter source order for equal dates.
      return lhs.offset < rhs.offset
    }.map(\.element)
  }

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
        Label("No entries yet", systemImage: "arrow.down.left.circle")
      } description: {
        Text("Money owed to you will appear here.")
      } actions: {
        Button("Add Entry", action: onAdd)
          .buttonStyle(.borderedProminent)
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          OwedToMeSummaryCard(totalText: store.owedToMeTotalText)
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Entries")
              .font(.title3.weight(.bold))
            Spacer(minLength: 8)
            Text("\(store.owedToMeEntryCount)")
              .font(.headline)
              .foregroundStyle(.secondary)
            OwedToMeSortButton(sortOrder: $sortOrder, reduceMotion: reduceMotion)
          }
          .padding(.top, 0)
          OwedToMeGroupedList(
            entries: filteredEntries,
            onEntrySelected: onEntrySelected
          )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 88)
      }
      .scrollIndicators(.hidden)
    }
  }
}

@available(iOS 26.0, *)
private struct OwedToMeSummaryCard: View {
  let totalText: String

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 8) {
        Image(systemName: "arrow.down.left")
          .font(.headline.weight(.semibold))
          .foregroundStyle(.white)
          .frame(width: 48, height: 48)
          .background(.white.opacity(0.18), in: Circle())
          .overlay { Circle().stroke(.white.opacity(0.22), lineWidth: 1) }
        Spacer(minLength: 2)
        Text("Total Owed")
          .font(.headline.weight(.medium))
          .foregroundStyle(.white.opacity(0.96))
        Text(totalText)
          .font(.system(.title2, design: .rounded).weight(.bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.55)
          .layoutPriority(1)
      }
      .padding(16)
    }
    .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
    .background(
      LinearGradient(
        colors: [Color(red: 0.30, green: 0.59, blue: 0.98), Color(red: 0.04, green: 0.40, blue: 0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(alignment: .bottomTrailing) {
      ZStack {
        Circle()
          .stroke(.white.opacity(0.14), lineWidth: 28)
          .frame(width: 280, height: 280)
          .offset(x: 110, y: 112)
        Circle()
          .stroke(.white.opacity(0.12), lineWidth: 22)
          .frame(width: 190, height: 190)
          .offset(x: 86, y: 100)
      }
      .allowsHitTesting(false)
    }
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Total owed \(totalText)")
  }
}

private enum DateSortOrder: Equatable {
  case newestFirst
  case oldestFirst

  var symbolName: String { self == .newestFirst ? "arrow.down" : "arrow.up" }
  var spokenValue: String { self == .newestFirst ? "Newest first" : "Oldest first" }
  var hint: String {
    self == .newestFirst
      ? "Double tap to show oldest entries first"
      : "Double tap to show newest entries first"
  }
}

@available(iOS 26.0, *)
private struct OwedToMeSortButton: View {
  @Binding var sortOrder: DateSortOrder
  let reduceMotion: Bool

  var body: some View {
    Button {
      if reduceMotion {
        sortOrder = sortOrder == .newestFirst ? .oldestFirst : .newestFirst
      } else {
        withAnimation(.snappy) {
          sortOrder = sortOrder == .newestFirst ? .oldestFirst : .newestFirst
        }
      }
    } label: {
      Image(systemName: sortOrder.symbolName)
        .font(.headline.weight(.semibold))
        .frame(width: 44, height: 44)
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.plain)
    .background(.thinMaterial, in: Circle())
    .accessibilityLabel("Sort entries")
    .accessibilityValue(sortOrder.spokenValue)
    .accessibilityHint(sortOrder.hint)
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
          Divider().padding(.leading, 72)
        }
      }
    }
    .padding(.vertical, 2)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
    }
  }
}

@available(iOS 26.0, *)
private struct OwedToMeEntryRow: View {
  let entry: NativeEntryListItem

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "arrow.down.left")
        .font(.headline.weight(.semibold))
        .foregroundStyle(.blue)
        .frame(width: 48, height: 48)
        .background(Color.blue.opacity(0.12), in: Circle())
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.title)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .truncationMode(.tail)
        HStack(spacing: 6) {
          Image(systemName: "calendar")
            .font(.caption2)
          Text(entry.dateText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }
      Spacer(minLength: 8)
      Text(entry.amountText)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.blue)
        .lineLimit(1)
        .minimumScaleFactor(0.65)
      Image(systemName: "chevron.right")
        .font(.caption.weight(.bold))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 80)
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
