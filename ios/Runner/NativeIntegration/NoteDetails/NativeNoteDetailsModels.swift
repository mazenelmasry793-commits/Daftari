import Foundation

struct NativeNoteDetailsSnapshot: Equatable {
  let id: String
  let title: String
  let note: String
  let date: Date?
  let dateText: String
}

struct NativeNoteDetailsInput {
  let title: String
  let note: String
  let date: Date
}

enum NativeNoteDetailsAction: String {
  case save
  case delete
}
