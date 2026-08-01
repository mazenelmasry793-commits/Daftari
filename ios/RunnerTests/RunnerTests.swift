import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testNativeEntrySortDefaultsToNewestFirst() {
    let entries = [entry(id: "may", date: Date(timeIntervalSince1970: 100)),
                   entry(id: "aug", date: Date(timeIntervalSince1970: 200))]

    XCTAssertEqual(
      sortedNativeEntries(entries, order: .newestFirst).map(\.id),
      ["aug", "may"]
    )
  }

  func testNativeEntrySortTogglesOldestThenNewest() {
    let entries = [entry(id: "may", date: Date(timeIntervalSince1970: 100)),
                   entry(id: "aug", date: Date(timeIntervalSince1970: 200))]
    let newest = NativeEntryDateSortOrder.newestFirst
    let oldest = newest.toggled

    XCTAssertEqual(sortedNativeEntries(entries, order: oldest).map(\.id), ["may", "aug"])
    XCTAssertEqual(sortedNativeEntries(entries, order: oldest.toggled).map(\.id), ["aug", "may"])
  }

  func testNativeEntrySortPreservesSourceOrderForEqualDates() {
    let date = Date(timeIntervalSince1970: 100)
    let entries = [entry(id: "first", date: date), entry(id: "second", date: date)]

    XCTAssertEqual(sortedNativeEntries(entries, order: .oldestFirst).map(\.id), ["first", "second"])
    XCTAssertEqual(sortedNativeEntries(entries, order: .newestFirst).map(\.id), ["first", "second"])
  }

  private func entry(id: String, date: Date) -> NativeEntryListItem {
    NativeEntryListItem(
      id: id,
      title: id,
      type: NativeEntryListType.owedToMe.rawValue,
      amountText: "€ 1.00",
      dateText: "Aug 1, 2026",
      date: date
    )
  }

}
