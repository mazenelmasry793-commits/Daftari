import Foundation

struct NativeDashboardEntry: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let amountText: String
  let dateText: String

  var typeLabel: String {
    switch type {
    case "owedToMe": return "To Me"
    case "owedByMe": return "I Owe"
    default: return "Note"
    }
  }

  var symbolName: String {
    switch type {
    case "owedToMe": return "arrow.down.left"
    case "owedByMe": return "arrow.up.right"
    default: return "note.text"
    }
  }

  var tint: ColorValue {
    switch type {
    case "owedToMe": return .blue
    case "owedByMe": return .orange
    default: return .indigo
    }
  }
}

enum ColorValue {
  case blue
  case orange
  case indigo
}

struct NativeDashboardSnapshot: Equatable {
  let schemaVersion: Int
  let owedToMeText: String
  let iOweText: String
  let recentCount: Int
  let recentEntries: [NativeDashboardEntry]
}
