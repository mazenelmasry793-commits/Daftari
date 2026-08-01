import UIKit

final class NativeSettingsButtonView: UIButton {
  var onSettingsRequested: (() -> Void)?

  init() {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    accessibilityLabel = "Settings"
    accessibilityTraits = .button
    setButtonConfiguration()
    addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
    isHidden = true
    alpha = 0
    isUserInteractionEnabled = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setVisible(_ visible: Bool, animated: Bool) {
    isUserInteractionEnabled = visible
    let update = {
      self.alpha = visible ? 1 : 0
      self.isHidden = !visible
    }
    if animated {
      UIView.animate(withDuration: 0.2, animations: update)
    } else {
      update()
    }
  }

  private func setButtonConfiguration() {
    let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
    let image = UIImage(systemName: "gearshape.fill", withConfiguration: symbolConfiguration)

    if #available(iOS 26.0, *) {
      var configuration = UIButton.Configuration.clearGlass()
      configuration.image = image
      configuration.baseForegroundColor = .label
      configuration.cornerStyle = .capsule
      self.configuration = configuration
    } else if #available(iOS 15.0, *) {
      var configuration = UIButton.Configuration.plain()
      configuration.image = image
      configuration.baseForegroundColor = .label
      configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
      self.configuration = configuration
    } else {
      setImage(image, for: .normal)
      tintColor = .label
    }
  }

  @objc private func settingsTapped() {
    if #available(iOS 10.0, *) {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    onSettingsRequested?()
  }
}
