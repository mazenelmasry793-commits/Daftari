import Foundation

enum NativeDebtType: String {
  case owedToMe
  case owedByMe
}

struct NativeDashboardEntry: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let amountText: String
  let dateText: String
  let previewText: String

  var typeLabel: String {
    switch type {
    case "owedToMe": return "To Me"
    case "owedByMe": return "I Owe"
    default: return ""
    }
  }

  var symbolName: String {
    switch type {
    case "owedToMe": return "arrow.down.left"
    case "owedByMe": return "arrow.up.right"
    default: return ""
    }
  }

  var tint: ColorValue {
    switch type {
    case "owedToMe": return .blue
    case "owedByMe": return .orange
    default: return .clear
    }
  }
}

enum ColorValue {
  case blue
  case orange
  case indigo
  case clear
}

struct NativeDashboardSnapshot: Equatable {
  let schemaVersion: Int
  let owedToMeText: String
  let iOweText: String
  let owedToMeEntryCount: Int
  let iOweEntryCount: Int
  let recentCount: Int
  let recentEntries: [NativeDashboardEntry]
}
