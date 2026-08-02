import Foundation

struct NativeEntryDetailsPayment: Identifiable, Equatable {
  let id: Int
  let amountText: String
  let dateText: String
  let note: String
}

struct NativeEntryDetailsSnapshot: Equatable {
  let id: String
  let title: String
  let type: String
  let status: String
  let dateText: String
  let note: String
  let originalText: String
  let paidText: String
  let remainingText: String
  let progress: Double
  let payments: [NativeEntryDetailsPayment]

  var isOwedToMe: Bool { type == "owedToMe" }
  var isDeleted: Bool { status == "deleted" }
  var isCompleted: Bool { status == "completed" }
}

enum NativeEntryDetailsAction: String {
  case edit
  case markCompleted
  case restore
  case delete
  case addPayment
  case deletePayment
}
