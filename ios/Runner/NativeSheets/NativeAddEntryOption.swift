import Foundation

enum NativeAddEntryOption: String, CaseIterable {
  case owedToMe = "owedToMe"
  case owedByMe = "owedByMe"
  case scratchpad = "scratchpad"

  var title: String {
    switch self {
    case .owedToMe: return "Owed To Me"
    case .owedByMe: return "Owed By Me"
    case .scratchpad: return "Scratchpad"
    }
  }

  var subtitle: String {
    switch self {
    case .owedToMe: return "Track money someone owes you."
    case .owedByMe: return "Track money you owe someone."
    case .scratchpad: return "Quick note or rough calculation."
    }
  }

  var sfSymbolName: String {
    switch self {
    case .owedToMe: return "arrow.down.left"
    case .owedByMe: return "arrow.up.right"
    case .scratchpad: return "note.text"
    }
  }

  var accessibilityHint: String {
    switch self {
    case .owedToMe: return "Creates a debt someone owes you."
    case .owedByMe: return "Creates a debt you owe someone."
    case .scratchpad: return "Creates a quick note or calculation."
    }
  }
}
