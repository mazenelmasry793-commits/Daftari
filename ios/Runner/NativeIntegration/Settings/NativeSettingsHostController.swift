import Flutter
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@available(iOS 26.0, *)
final class NativeSettingsHostController: UIViewController, UIDocumentPickerDelegate {
  private let onBack: () -> Void
  private let onTrash: () -> Void
  private let onExport: () -> Void
  private let onImportData: (String) -> Void
  private let onEmptyTrash: () -> Void
  private let onDeleteAllData: () -> Void

  init(
    onBack: @escaping () -> Void,
    onTrash: @escaping () -> Void,
    onExport: @escaping () -> Void,
    onImportData: @escaping (String) -> Void,
    onEmptyTrash: @escaping () -> Void,
    onDeleteAllData: @escaping () -> Void
  ) {
    self.onBack = onBack
    self.onTrash = onTrash
    self.onExport = onExport
    self.onImportData = onImportData
    self.onEmptyTrash = onEmptyTrash
    self.onDeleteAllData = onDeleteAllData
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func viewDidLoad() {
    super.viewDidLoad()
    let view = NativeSettingsView(
      onBack: onBack,
      onTrash: onTrash,
      onExport: onExport,
      onImport: { [weak self] in self?.presentDocumentPicker() },
      onEmptyTrash: onEmptyTrash,
      onDeleteAllData: onDeleteAllData
    )
    let host = UIHostingController(rootView: view)
    addChild(host)
    self.view.addSubview(host.view)
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: self.view.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
    ])
    host.didMove(toParent: self)
  }

  func presentExport(url: URL) {
    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if let popover = activity.popoverPresentationController {
      popover.sourceView = view
      popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
    }
    present(activity, animated: true)
  }

  private func presentDocumentPicker() {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
    picker.delegate = self
    picker.allowsMultipleSelection = false
    present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first else { return }
    do {
      onImportData(try String(contentsOf: url, encoding: .utf8))
    } catch {
      NativeSettingsBridge.presentError(on: self, message: "Import failed")
    }
  }
}

enum NativeSettingsBridge {
  static func presentError(on host: UIViewController, message: String) {
    let alert = UIAlertController(title: "Settings", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    host.present(alert, animated: true)
  }
}
