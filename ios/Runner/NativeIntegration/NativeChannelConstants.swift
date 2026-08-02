import Foundation

enum NativeChannelConstants {
  static let navigationChannel = "com.daftari/native_bottom_navigation"
  static let sheetsChannel = "com.daftari/native_sheets"
  static let toastChannel = "com.daftari/native_toast"
  static let dashboardChannel = "com.daftari/native_dashboard"
  static let entriesChannel = "com.daftari/native_entries"
  static let entryDetailsChannel = "com.daftari/native_entry_details"

  enum NavigationMethod {
    static let setSelectedTab = "setSelectedTab"
    static let setNavigationVisible = "setNavigationVisible"
    static let nativeTabSelected = "nativeTabSelected"
    static let openAddEntry = "openAddEntry"
    static let openSettings = "openSettings"
  }

  enum SheetMethod {
    static let showAddEntryChooser = "showAddEntryChooser"
    static let showNativeEntryForm = "showNativeEntryForm"
    static let showNativeDatePicker = "showNativeDatePicker"
    static let addEntryTypeSelected = "addEntryTypeSelected"
    static let addEntryChooserDismissed = "addEntryChooserDismissed"
    static let nativeEntryFormSubmitted = "nativeEntryFormSubmitted"
  }

  enum ToastMethod {
    static let showToast = "showToast"
    static let dismissToast = "dismissToast"
  }

  enum DashboardMethod {
    static let snapshotUpdated = "dashboardSnapshotUpdated"
    static let dashboardReady = "dashboardReady"
    static let openEntryDetails = "openEntryDetails"
  }

  enum EntriesMethod {
    static let snapshotUpdated = "entriesSnapshotUpdated"
    static let openEntryDetails = "openEntryDetails"
  }

  enum EntryDetailsMethod {
    static let loadEntry = "loadEntry"
    static let performAction = "performAction"
    static let snapshotUpdated = "entryDetailsSnapshotUpdated"
    static let close = "closeEntryDetails"
  }
}
