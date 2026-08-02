import Flutter
import Foundation

final class NativeNoteDetailsBridge {
  let store = NativeNoteDetailsStore()
  private let channel: FlutterMethodChannel
  private var actionInFlight = false
  var onRequestClose: (() -> Void)?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.daftari/native_note_details",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "noteDetailsSnapshotUpdated":
        self.store.apply(payload: call.arguments)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func load(id: String) {
    store.beginLoading()
    channel.invokeMethod("loadNote", arguments: ["id": id]) { [weak self] value in
      DispatchQueue.main.async { self?.store.apply(payload: value) }
    }
  }

  func perform(
    action: NativeNoteDetailsAction,
    id: String,
    input: NativeNoteDetailsInput? = nil,
    completion: ((Bool) -> Void)? = nil
  ) {
    guard !actionInFlight else { return }
    actionInFlight = true
    var arguments: [String: Any] = ["id": id, "action": action.rawValue]
    if let input {
      arguments["title"] = input.title
      arguments["note"] = input.note
      arguments["dateIso8601"] = ISO8601DateFormatter().string(from: input.date)
    }
    channel.invokeMethod("performAction", arguments: arguments) { [weak self] value in
      DispatchQueue.main.async {
        guard let self else { return }
        self.actionInFlight = false
        guard let payload = value as? [String: Any] else {
          completion?(false)
          return
        }
        self.store.apply(payload: payload)
        let close = payload["close"] as? Bool == true
        completion?(payload["actionSucceeded"] as? Bool ?? !close)
        if close { self.onRequestClose?() }
      }
    }
  }

  deinit { channel.setMethodCallHandler(nil) }
}
