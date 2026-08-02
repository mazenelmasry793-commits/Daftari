import Flutter

final class NativeEntryDetailsBridge {
  let store = NativeEntryDetailsStore()
  private let channel: FlutterMethodChannel
  var onRequestClose: (() -> Void)?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: NativeChannelConstants.entryDetailsChannel,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case NativeChannelConstants.EntryDetailsMethod.snapshotUpdated:
        self.store.apply(payload: call.arguments)
        result(nil)
      case NativeChannelConstants.EntryDetailsMethod.close:
        self.onRequestClose?()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func load(id: String) {
    store.beginLoading()
    channel.invokeMethod(
      NativeChannelConstants.EntryDetailsMethod.loadEntry,
      arguments: ["id": id]
    ) { [weak self] result in
      DispatchQueue.main.async { self?.store.apply(payload: result) }
    }
  }

  func perform(
    action: NativeEntryDetailsAction,
    id: String,
    paymentID: Int? = nil
  ) {
    var arguments: [String: Any] = ["id": id, "action": action.rawValue]
    if let paymentID { arguments["paymentID"] = paymentID }
    channel.invokeMethod(
      NativeChannelConstants.EntryDetailsMethod.performAction,
      arguments: arguments
    ) { [weak self] result in
      DispatchQueue.main.async {
        guard let payload = result as? [String: Any] else { return }
        self?.store.apply(payload: payload)
        if payload["close"] as? Bool == true { self?.onRequestClose?() }
      }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
}
