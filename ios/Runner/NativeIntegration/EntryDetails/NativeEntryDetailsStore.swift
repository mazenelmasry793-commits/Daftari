import Combine

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
          let dateText = rawEntry["dateText"] as? String,
          let originalText = rawEntry["originalText"] as? String,
          let paidText = rawEntry["paidText"] as? String,
          let remainingText = rawEntry["remainingText"] as? String,
          let progress = rawEntry["progress"] as? Double,
          let rawPayments = rawEntry["payments"] as? [[String: Any]] else {
      isLoading = false
      errorMessage = "Entry details unavailable"
      return
    }

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
      progress: min(max(progress, 0), 1),
      payments: payments
    )
    isLoading = false
    errorMessage = nil
  }
}
