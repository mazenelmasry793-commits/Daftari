import Combine
import Foundation

final class NativeSearchStore: ObservableObject {
  @Published private(set) var query = ""
  @Published private(set) var results: [NativeSearchResult] = []

  func setQuery(_ query: String) {
    self.query = query
    results = []
  }

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any] else { return }
    if let query = payload["query"] as? String { self.query = query }
    guard let rawResults = payload["results"] as? [[String: Any]] else {
      results = []
      return
    }
    results = rawResults.compactMap { raw in
      guard let id = raw["id"] as? String,
            let title = raw["title"] as? String,
            let type = raw["type"] as? String,
            let dateText = raw["dateText"] as? String else { return nil }
      return NativeSearchResult(
        id: id,
        title: title,
        type: type,
        dateText: dateText,
        amountText: raw["amountText"] as? String,
        previewText: raw["previewText"] as? String ?? ""
      )
    }
  }
}
