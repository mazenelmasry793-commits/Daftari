import Foundation

enum NativeEntryFormType: String {
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

  var amountPlaceholder: String {
    self == .scratchpad ? "Amount (optional)" : "Amount"
  }
}

struct NativeEntryFormPayload {
  let type: NativeEntryFormType
  let title: String
  let amount: Double?
  let note: String
  let debtDate: Date

  var dictionary: [String: Any] {
    var result: [String: Any] = [
      "type": type.rawValue,
      "title": title,
      "note": note,
      "debtDate": ISO8601DateFormatter().string(from: debtDate),
    ]
    if let amount {
      result["amount"] = amount
    }
    return result
  }
}
