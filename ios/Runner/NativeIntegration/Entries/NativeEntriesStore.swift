import Combine

final class NativeEntriesStore: ObservableObject {
  @Published private(set) var entries: [NativeEntryListItem] = []
  @Published private(set) var owedToMeTotalText = "€ 0.00"
  @Published private(set) var owedToMeEntryCount = 0
  @Published private(set) var iOweTotalText = "€ 0.00"
  @Published private(set) var iOweEntryCount = 0
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
      return NativeEntryListItem(
        id: id,
        title: title,
        type: type,
        amountText: amountText,
        dateText: dateText
      )
    }
    owedToMeTotalText = payload["owedToMeText"] as? String ?? "€ 0.00"
    owedToMeEntryCount = payload["owedToMeEntryCount"] as? Int
      ?? entries.filter { $0.type == NativeEntryListType.owedToMe.rawValue }.count
    iOweTotalText = payload["iOweText"] as? String ?? "€ 0.00"
    iOweEntryCount = payload["iOweEntryCount"] as? Int
      ?? entries.filter { $0.type == NativeEntryListType.owedByMe.rawValue }.count
    errorMessage = nil
  }

  func entries(for type: NativeEntryListType) -> [NativeEntryListItem] {
    entries.filter { $0.type == type.rawValue }
  }
}
