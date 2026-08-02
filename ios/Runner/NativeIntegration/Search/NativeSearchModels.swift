import Foundation

struct NativeSearchResult: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let dateText: String
  let amountText: String?
  let previewText: String

  var sectionTitle: String {
    switch type {
    case "owedToMe": return "To Me"
    case "owedByMe": return "I Owe"
    default: return "Notes"
    }
  }

  var tint: String {
    switch type {
    case "owedToMe": return "blue"
    case "owedByMe": return "orange"
    default: return "purple"
    }
  }

  var symbolName: String {
    switch type {
    case "owedToMe": return "arrow.down.left"
    case "owedByMe": return "arrow.up.right"
    default: return "note.text"
    }
  }
}
