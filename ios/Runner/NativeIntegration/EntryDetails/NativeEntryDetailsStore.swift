import Combine
import Foundation

final class NativeEntryDetailsStore: ObservableObject {
  @Published private(set) var snapshot: NativeEntryDetailsSnapshot?
  @Published private(set) var errorMessage: String?
  @Published private(set) var isLoading = false

  func beginLoading() {
    isLoading = true
    errorMessage = nil
  }

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any],
          let rawEntry = payload["entry"] as? [String: Any],
          let id = rawEntry["id"] as? String,
          let title = rawEntry["title"] as? String,
          let type = rawEntry["type"] as? String,
          let status = rawEntry["status"] as? String,
          let fallbackDateText = rawEntry["dateText"] as? String,
          let originalText = rawEntry["originalText"] as? String,
          let paidText = rawEntry["paidText"] as? String,
          let remainingText = rawEntry["remainingText"] as? String,
          let rawPayments = rawEntry["payments"] as? [[String: Any]] else {
      isLoading = false
      errorMessage = "Entry details unavailable"
      return
    }

    let dateText = formattedDate(
      iso8601: rawEntry["dateIso8601"] as? String,
      fallback: fallbackDateText
    )
    let progress = min(max((rawEntry["progress"] as? NSNumber)?.doubleValue ?? 0, 0), 1)
    let payments = rawPayments.compactMap { raw -> NativeEntryDetailsPayment? in
      guard let id = raw["id"] as? Int,
            let amountText = raw["amountText"] as? String,
            let dateText = raw["dateText"] as? String else { return nil }
      return NativeEntryDetailsPayment(
        id: id,
        amountText: amountText,
        dateText: dateText,
        note: raw["note"] as? String ?? ""
      )
    }

    snapshot = NativeEntryDetailsSnapshot(
      id: id,
      title: title,
      type: type,
      status: status,
      dateText: dateText,
      note: rawEntry["note"] as? String ?? "",
      originalText: originalText,
      paidText: paidText,
      remainingText: remainingText,
      progress: progress,
      payments: payments
    )
    isLoading = false
    errorMessage = nil
  }

  private func formattedDate(iso8601: String?, fallback: String) -> String {
    guard let iso8601,
          let date = ISO8601DateFormatter().date(from: iso8601) else {
      return fallback
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = .current
    return formatter.string(from: date)
  }
}
