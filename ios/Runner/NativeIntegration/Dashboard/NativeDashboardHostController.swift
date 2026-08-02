import SwiftUI
import UIKit

@available(iOS 26.0, *)
final class NativeDashboardHostController: UIViewController {
  private let dashboardBridge: NativeDashboardBridge
  private let hostingController: UIHostingController<NativeDashboardView>
  private let onAddEntryTypeSelected: (String) -> Void
  private let onSettingsRequested: () -> Void
  private let onEntrySelected: (String, String) -> Void

  init(
    dashboardBridge: NativeDashboardBridge,
    onAddEntryTypeSelected: @escaping (String) -> Void,
    onSettingsRequested: @escaping () -> Void,
    onEntrySelected: @escaping (String, String) -> Void
  ) {
    self.dashboardBridge = dashboardBridge
    self.onAddEntryTypeSelected = onAddEntryTypeSelected
    self.onSettingsRequested = onSettingsRequested
    self.onEntrySelected = onEntrySelected
    let view = NativeDashboardView(
      store: dashboardBridge.store,
      onAddEntryTypeSelected: onAddEntryTypeSelected,
      onSettingsRequested: onSettingsRequested,
      onEntrySelected: onEntrySelected
    )
    hostingController = UIHostingController(rootView: view)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    hostingController.didMove(toParent: self)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    dashboardBridge.dashboardReady()
  }
}
