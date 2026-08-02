import Foundation

enum NativeAddEntryOption: String, CaseIterable {
  case owedToMe = "owedToMe"
  case owedByMe = "owedByMe"

  var title: String {
    switch self {
    case .owedToMe: return "Owed To Me"
    case .owedByMe: return "Owed By Me"
    }
  }

  var subtitle: String {
    switch self {
    case .owedToMe: return "Track money someone owes you."
    case .owedByMe: return "Track money you owe someone."
    }
  }

  var sfSymbolName: String {
    switch self {
    case .owedToMe: return "arrow.down.left"
    case .owedByMe: return "arrow.up.right"
    }
  }

  var accessibilityHint: String {
    switch self {
    case .owedToMe: return "Creates a debt someone owes you."
    case .owedByMe: return "Creates a debt you owe someone."
    }
  }
}
