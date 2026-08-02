import Foundation

struct NativeTrashEntry: Identifiable, Equatable {
  let id: String
  let title: String
  let type: String
  let dateText: String
  let amountText: String?

  var typeText: String {
    switch type {
    case "owedToMe": return "Owed To Me"
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
}
