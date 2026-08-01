import Combine
import Foundation

final class NativeEntriesStore: ObservableObject {
  @Published private(set) var entries: [NativeEntryListItem] = []
  @Published private(set) var owedToMeTotalText = "€ 0.00"
  @Published private(set) var owedToMeEntryCount = 0
  @Published private(set) var iOweTotalText = "€ 0.00"
  @Published private(set) var iOweEntryCount = 0
  @Published private(set) var errorMessage: String?

  private let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

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
      let updatedAt = (raw["updatedAtIso8601"] as? String)
        .flatMap(iso8601Formatter.date(from:)) ?? .distantPast
      return NativeEntryListItem(
        id: id,
        title: title,
        type: type,
        amountText: amountText,
        dateText: dateText,
        previewText: raw["previewText"] as? String ?? "",
        updatedAt: updatedAt,
        updatedAtText: raw["updatedAtText"] as? String ?? dateText
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
