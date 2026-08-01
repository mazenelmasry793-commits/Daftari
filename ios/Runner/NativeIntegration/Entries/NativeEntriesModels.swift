import Foundation

struct NativeEntryListItem: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let amountText: String
  let dateText: String
  let date: Date

  var isNote: Bool { type == "scratchpad" }

  var symbolName: String {
    switch type {
    case "owedToMe": return "arrow.down.left"
    case "owedByMe": return "arrow.up.right"
    default: return "note.text"
    }
  }
}

enum NativeEntryDateSortOrder: Equatable {
  case newestFirst
  case oldestFirst

  var toggled: NativeEntryDateSortOrder {
    self == .newestFirst ? .oldestFirst : .newestFirst
  }

  var symbolName: String { self == .newestFirst ? "arrow.down" : "arrow.up" }
  var spokenValue: String { self == .newestFirst ? "Newest first" : "Oldest first" }
  var hint: String {
    self == .newestFirst
      ? "Double tap to show oldest entries first"
      : "Double tap to show newest entries first"
  }
}

/// Sorts only the native presentation collection, preserving source order for
/// equal dates so Flutter's canonical ordering remains deterministic.
func sortedNativeEntries(
  _ entries: [NativeEntryListItem],
  order: NativeEntryDateSortOrder
) -> [NativeEntryListItem] {
  entries.enumerated()
    .sorted { lhs, rhs in
      if lhs.element.date != rhs.element.date {
        return order == .newestFirst
          ? lhs.element.date > rhs.element.date
          : lhs.element.date < rhs.element.date
      }
      return lhs.offset < rhs.offset
    }
    .map(\.element)
}

enum NativeEntryListType: String {
  case owedToMe
  case owedByMe
  case scratchpad

  var title: String {
    switch self {
    case .owedToMe: return "Owed To Me"
    case .owedByMe: return "Owed By Me"
    case .scratchpad: return "Scratchpad"
    }
  }

  var emptyTitle: String {
    switch self {
    case .owedToMe: return "Nothing owed to you yet"
    case .owedByMe: return "Nothing owed by you"
    case .scratchpad: return "Your scratchpad is empty"
    }
  }

  var emptyMessage: String {
    switch self {
    case .owedToMe: return "Add a debt here when someone owes you money."
    case .owedByMe: return "Add a debt here when you owe money to someone."
    case .scratchpad: return "Use it for quick notes, rough calculations, or unfinished ideas."
    }
  }

  var symbolName: String {
    switch self {
    case .owedToMe: return "arrow.down.left.circle"
    case .owedByMe: return "arrow.up.right.circle"
    case .scratchpad: return "note.text"
    }
  }
}
