import Flutter
import Foundation

final class NativeDashboardBridge {
  let store = NativeDashboardStore()
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: NativeChannelConstants.dashboardChannel,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case NativeChannelConstants.DashboardMethod.snapshotUpdated:
        self.store.apply(payload: call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func dashboardReady() {
    channel.invokeMethod(NativeChannelConstants.DashboardMethod.dashboardReady, arguments: nil)
  }

  func openEntryDetails(id: String) {
    channel.invokeMethod(
      NativeChannelConstants.DashboardMethod.openEntryDetails,
      arguments: ["id": id]
    )
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}
