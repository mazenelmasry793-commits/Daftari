import Combine

final class NativeEntriesStore: ObservableObject {
  @Published private(set) var entries: [NativeEntryListItem] = []
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
    errorMessage = nil
  }

  func entries(for type: NativeEntryListType) -> [NativeEntryListItem] {
    entries.filter { $0.type == type.rawValue }
  }
}
