import Foundation

struct NativeEntryListItem: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let amountText: String
  let dateText: String
  let previewText: String
  let updatedAt: Date
  let updatedAtText: String

  var symbolName: String {
    switch type {
    case "owedToMe": return "arrow.down.left"
    case "owedByMe": return "arrow.up.right"
    default: return ""
    }
  }
}

enum NativeEntryListType: String {
  case owedToMe
  case owedByMe

  var title: String {
    switch self {
    case .owedToMe: return "Owed To Me"
    case .owedByMe: return "Owed By Me"
    }
  }

  var emptyTitle: String {
    switch self {
    case .owedToMe: return "Nothing owed to you yet"
    case .owedByMe: return "Nothing owed by you"
    }
  }

  var emptyMessage: String {
    switch self {
    case .owedToMe: return "Add a debt here when someone owes you money."
    case .owedByMe: return "Add a debt here when you owe money to someone."
    }
  }

  var symbolName: String {
    switch self {
    case .owedToMe: return "arrow.down.left.circle"
    case .owedByMe: return "arrow.up.right.circle"
    }
  }
}
