import Foundation

enum NativeChannelConstants {
  static let navigationChannel = "com.daftari/native_bottom_navigation"
  static let sheetsChannel = "com.daftari/native_sheets"

  enum NavigationMethod {
    static let setSelectedTab = "setSelectedTab"
    static let setNavigationVisible = "setNavigationVisible"
    static let nativeTabSelected = "nativeTabSelected"
    static let openAddEntry = "openAddEntry"
  }

  enum SheetMethod {
    static let showAddEntryChooser = "showAddEntryChooser"
    static let showNativeDatePicker = "showNativeDatePicker"
    static let addEntryTypeSelected = "addEntryTypeSelected"
    static let addEntryChooserDismissed = "addEntryChooserDismissed"
  }
}
