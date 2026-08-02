import Flutter

final class NativeEntryDetailsBridge {
  let store = NativeEntryDetailsStore()
  private let channel: FlutterMethodChannel
  private var actionInFlight = false
  private var currentID: String?
  var currentEntryID: String? { currentID }
  var onRequestClose: (() -> Void)?
  var onActionFinished: ((String, Bool) -> Void)?

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
    currentID = id
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
    paymentID: Int? = nil,
    payment: NativeEntryDetailsPaymentInput? = nil,
    completion: ((Bool) -> Void)? = nil
  ) {
    guard !actionInFlight else { return }
    actionInFlight = true
    var arguments: [String: Any] = ["id": id, "action": action.rawValue]
    if let paymentID { arguments["paymentID"] = paymentID }
    if let payment {
      arguments["amount"] = payment.amount
      arguments["dateIso8601"] = ISO8601DateFormatter().string(from: payment.date)
      arguments["note"] = payment.note
    }
    channel.invokeMethod(
      NativeChannelConstants.EntryDetailsMethod.performAction,
      arguments: arguments
    ) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        guard let payload = result as? [String: Any] else {
          self.actionInFlight = false
          completion?(false)
          self.onActionFinished?(id, false)
          return
        }
        self.store.apply(payload: payload)
        let close = payload["close"] as? Bool == true
        self.actionInFlight = false
        completion?(payload["actionSucceeded"] as? Bool ?? !close)
        if close { self.onRequestClose?() }
        self.onActionFinished?(id, close)
      }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
}
