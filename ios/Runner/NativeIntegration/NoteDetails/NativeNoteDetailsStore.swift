import Combine
import Foundation

final class NativeNoteDetailsStore: ObservableObject {
  @Published private(set) var snapshot: NativeNoteDetailsSnapshot?
  @Published private(set) var isLoading = false
  @Published private(set) var errorMessage: String?

  func beginLoading() {
    isLoading = true
    errorMessage = nil
  }

  func apply(payload: Any?) {
    guard let payload = payload as? [String: Any],
          let raw = payload["note"] as? [String: Any],
          let id = raw["id"] as? String,
          let title = raw["title"] as? String,
          let note = raw["note"] as? String else {
      isLoading = false
      return
    }

    let date = (raw["dateEpochMs"] as? NSNumber)
      .map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
      ?? parseDate(raw["dateIso8601"] as? String)
    let formattedDate = formatDate(date, fallback: raw["dateText"] as? String)
    let finalDateText = formattedDate.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !finalDateText.isEmpty else {
      errorMessage = "Note date unavailable"
      isLoading = false
      return
    }
    snapshot = NativeNoteDetailsSnapshot(
      id: id,
      title: title,
      note: note,
      date: date,
      dateText: finalDateText
    )
    isLoading = false
    errorMessage = nil
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private func formatDate(_ date: Date?, fallback: String?) -> String {
    guard let date else { return fallback?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    if #available(iOS 15.0, *) {
      let formatted = date.formatted(
        Date.FormatStyle(date: .abbreviated, time: .omitted)
          .locale(Locale.current)
      )
      return formatted.isEmpty ? (fallback ?? "") : formatted
    }
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = .current
    return formatter.string(from: date).isEmpty ? (fallback ?? "") : formatter.string(from: date)
  }
}
