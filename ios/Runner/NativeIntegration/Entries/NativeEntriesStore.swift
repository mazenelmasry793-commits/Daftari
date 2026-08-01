import Combine
import Foundation

final class NativeEntriesStore: ObservableObject {
  @Published private(set) var entries: [NativeEntryListItem] = []
  @Published private(set) var owedToMeTotalText = "€ 0.00"
  @Published private(set) var owedToMeEntryCount = 0
  @Published private(set) var errorMessage: String?

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any],
          let rawEntries = payload["entries"] as? [[String: Any]] else {
      errorMessage = "Invalid entries snapshot"
      return
    }

    entries = rawEntries.compactMap { raw in
      guard let id = raw["id"] as? String,
            let title = raw["title"] as? String,
            let type = raw["type"] as? String,
            let amountText = raw["amountText"] as? String,
            let dateText = raw["dateText"] as? String else { return nil }
      let date: Date
      if let dateIso8601 = raw["dateIso8601"] as? String,
         let parsedDate = ISO8601DateFormatter().date(from: dateIso8601) {
        date = parsedDate
      } else {
        // Keep older snapshots renderable while newer snapshots provide the
        // canonical sortable timestamp.
        date = .distantPast
      }
      return NativeEntryListItem(
        id: id,
        title: title,
        type: type,
        amountText: amountText,
        dateText: dateText,
        date: date
      )
    }
    owedToMeTotalText = payload["owedToMeText"] as? String ?? "€ 0.00"
    owedToMeEntryCount = payload["owedToMeEntryCount"] as? Int
      ?? entries.filter { $0.type == NativeEntryListType.owedToMe.rawValue }.count
    errorMessage = nil
  }

  func entries(for type: NativeEntryListType) -> [NativeEntryListItem] {
    entries.filter { $0.type == type.rawValue }
  }
}
