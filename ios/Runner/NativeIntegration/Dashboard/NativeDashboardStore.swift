import Foundation
import Combine

final class NativeDashboardStore: ObservableObject {
  @Published private(set) var snapshot: NativeDashboardSnapshot?
  @Published private(set) var errorMessage: String?

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any] else {
      errorMessage = "Invalid dashboard payload"
      return
    }
    guard let schemaVersion = payload["schemaVersion"] as? Int,
          schemaVersion == 1,
          let owedToMeText = payload["owedToMeText"] as? String,
          let iOweText = payload["iOweText"] as? String,
          let recentCount = payload["totalRecentCount"] as? Int,
          let rawEntries = payload["recentEntries"] as? [[String: Any]] else {
      errorMessage = "Unsupported dashboard snapshot"
      return
    }

    let entries = rawEntries.compactMap { raw -> NativeDashboardEntry? in
      guard let id = raw["id"] as? String,
            let title = raw["title"] as? String,
            let type = raw["type"] as? String,
            let amountText = raw["amountText"] as? String,
            let dateText = raw["dateText"] as? String else {
        return nil
      }
      return NativeDashboardEntry(
        id: id,
        title: title,
        type: type,
        amountText: amountText,
        dateText: dateText
      )
    }

    errorMessage = nil
    snapshot = NativeDashboardSnapshot(
      schemaVersion: schemaVersion,
      owedToMeText: owedToMeText,
      iOweText: iOweText,
      recentCount: recentCount,
      recentEntries: entries
    )
  }
}
