import Combine
import Foundation

final class NativeTrashStore: ObservableObject {
  @Published private(set) var entries: [NativeTrashEntry] = []
  @Published private(set) var actionInFlight = false
  @Published private(set) var errorMessage: String?

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any],
          let rawEntries = payload["entries"] as? [[String: Any]] else {
      errorMessage = "Invalid Trash snapshot"
      return
    }

    entries = rawEntries.compactMap { raw in
      guard let id = raw["id"] as? String,
            let title = raw["title"] as? String,
            let type = raw["type"] as? String,
            NativeDebtType(rawValue: type) != nil,
            let dateText = raw["dateText"] as? String,
            !dateText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
      }
      return NativeTrashEntry(
        id: id,
        title: title,
        type: type,
        dateText: dateText,
        amountText: raw["amountText"] as? String
      )
    }
    errorMessage = nil
  }

  func setActionInFlight(_ value: Bool) {
    actionInFlight = value
  }
}
