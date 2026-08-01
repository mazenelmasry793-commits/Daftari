import Flutter

final class NativeEntriesBridge {
  let store = NativeEntriesStore()
  private let channel: FlutterMethodChannel

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: NativeChannelConstants.entriesChannel,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case NativeChannelConstants.EntriesMethod.snapshotUpdated:
        self.store.apply(payload: call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func openEntryDetails(id: String) {
    channel.invokeMethod(
      NativeChannelConstants.EntriesMethod.openEntryDetails,
      arguments: ["id": id]
    )
  }

  deinit { channel.setMethodCallHandler(nil) }
}
