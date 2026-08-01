import Flutter
import UIKit

private enum NativeToastType: String {
  case success
  case error
  case warning
  case info

  var symbolName: String {
    switch self {
    case .success: return "checkmark.circle.fill"
    case .error: return "xmark.circle.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .info: return "info.circle.fill"
    }
  }

  var tintColor: UIColor {
    switch self {
    case .success: return .systemGreen
    case .error: return .systemRed
    case .warning: return .systemOrange
    case .info: return .systemBlue
    }
  }
}

private final class NativeToastView: UIView {
  init(message: String, type: NativeToastType) {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    isAccessibilityElement = true
    accessibilityLabel = message
    accessibilityTraits = .updatesFrequently
    isUserInteractionEnabled = false

    let effectView: UIVisualEffectView
    if #available(iOS 26.0, *) {
      effectView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    } else {
      effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }
    effectView.translatesAutoresizingMaskIntoConstraints = false
    effectView.layer.cornerRadius = 22
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    addSubview(effectView)

    let iconView = UIImageView(
      image: UIImage(systemName: type.symbolName)
    )
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.tintColor = type.tintColor
    iconView.contentMode = .scaleAspectFit
    iconView.accessibilityElementsHidden = true

    let messageLabel = UILabel()
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    messageLabel.text = message
    messageLabel.font = .preferredFont(forTextStyle: .subheadline)
    messageLabel.adjustsFontForContentSizeCategory = true
    messageLabel.textColor = .label
    messageLabel.numberOfLines = 2
    messageLabel.lineBreakMode = .byTruncatingTail

    effectView.contentView.addSubview(iconView)
    effectView.contentView.addSubview(messageLabel)
    NSLayoutConstraint.activate([
      effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      effectView.topAnchor.constraint(equalTo: topAnchor),
      effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
      iconView.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor, constant: 16),
      iconView.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 22),
      iconView.heightAnchor.constraint(equalToConstant: 22),
      messageLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
      messageLabel.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor, constant: -16),
      messageLabel.topAnchor.constraint(greaterThanOrEqualTo: effectView.contentView.topAnchor, constant: 11),
      messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: effectView.contentView.bottomAnchor, constant: -11),
      messageLabel.centerYAnchor.constraint(equalTo: effectView.contentView.centerYAnchor),
      heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

final class NativeToastPresenter {
  private let hostView: UIView
  private var currentToast: NativeToastView?
  private var dismissWorkItem: DispatchWorkItem?
  private var lastMessage: String?
  private var lastShownAt: Date?

  // The 83 pt native navigation row plus a 12 pt visual breathing gap.
  private let bottomSpacingAboveNavigation: CGFloat = 95

  init(hostView: UIView) {
    self.hostView = hostView
  }

  func show(message: String, type: String, durationMilliseconds: Int) {
    let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !message.isEmpty else { return }
    guard let toastType = NativeToastType(rawValue: type) else { return }

    let now = Date()
    if lastMessage == message,
       let lastShownAt,
       now.timeIntervalSince(lastShownAt) < 0.6 {
      return
    }
    lastMessage = message
    lastShownAt = now

    dismissWorkItem?.cancel()
    currentToast?.layer.removeAllAnimations()
    currentToast?.removeFromSuperview()

    let toast = NativeToastView(message: message, type: toastType)
    currentToast = toast
    hostView.addSubview(toast)
    NSLayoutConstraint.activate([
      toast.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 20),
      toast.trailingAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -20),
      toast.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
      toast.bottomAnchor.constraint(
        equalTo: hostView.safeAreaLayoutGuide.bottomAnchor,
        constant: -bottomSpacingAboveNavigation
      ),
      toast.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
    ])

    hostView.layoutIfNeeded()
    toast.alpha = 0
    toast.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.96, y: 0.96)
    let animations = {
      toast.alpha = 1
      toast.transform = .identity
    }
    if UIAccessibility.isReduceMotionEnabled {
      animations()
    } else {
      UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseOut], animations: animations)
    }
    UIAccessibility.post(notification: .announcement, argument: message)

    let workItem = DispatchWorkItem { [weak self, weak toast] in
      guard let self, let toast, self.currentToast === toast else { return }
      let dismiss = {
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 8).scaledBy(x: 0.96, y: 0.96)
      }
      let complete = { [weak self, weak toast] in
        toast?.removeFromSuperview()
        if self?.currentToast === toast {
          self?.currentToast = nil
        }
      }
      if UIAccessibility.isReduceMotionEnabled {
        dismiss()
        complete()
      } else {
        UIView.animate(withDuration: 0.2, animations: dismiss) { _ in complete() }
      }
    }
    dismissWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .milliseconds(max(1400, min(durationMilliseconds, 6000))),
      execute: workItem
    )
  }

  func dismiss() {
    dismissWorkItem?.cancel()
    dismissWorkItem = nil
    currentToast?.removeFromSuperview()
    currentToast = nil
  }
}

final class NativeToastCoordinator {
  private let presenter: NativeToastPresenter
  private var channel: FlutterMethodChannel?

  init(rootView: UIView) {
    presenter = NativeToastPresenter(hostView: rootView)
  }

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: NativeChannelConstants.toastChannel,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case NativeChannelConstants.ToastMethod.showToast:
        let arguments = call.arguments as? [String: Any]
        let message = arguments?["message"] as? String ?? ""
        let type = arguments?["type"] as? String ?? NativeToastType.info.rawValue
        let duration = arguments?["durationMs"] as? Int ?? 2200
        DispatchQueue.main.async { [weak self] in
          self?.presenter.show(message: message, type: type, durationMilliseconds: duration)
        }
        result(nil)
      case NativeChannelConstants.ToastMethod.dismissToast:
        DispatchQueue.main.async { [weak self] in self?.presenter.dismiss() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  deinit {
    channel?.setMethodCallHandler(nil)
  }
}
