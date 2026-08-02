import UIKit
import SwiftUI

@available(iOS 26.0, *)
final class DaftariSearchHostViewController: UIViewController, UISearchResultsUpdating, UISearchControllerDelegate {
  var onSearchBegan: (() -> Void)?
  var onSearchDismissalBegan: (() -> Void)?

  private let onQueryChanged: (String) -> Void
  private let onDismissed: () -> Void
  private let searchController = UISearchController(searchResultsController: nil)
  private let store = NativeSearchStore()
  private let onResultSelected: (String, String) -> Void
  private var hostingController: UIHostingController<NativeSearchView>?

  init(
    onQueryChanged: @escaping (String) -> Void,
    onDismissed: @escaping () -> Void,
    onResultSelected: @escaping (String, String) -> Void
  ) {
    self.onQueryChanged = onQueryChanged
    self.onDismissed = onDismissed
    self.onResultSelected = onResultSelected
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    view.isOpaque = true
    definesPresentationContext = true
    searchController.searchResultsUpdater = self
    searchController.delegate = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.hidesNavigationBarDuringPresentation = false
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
    if #available(iOS 26.0, *) {
      let host = UIHostingController(
        rootView: NativeSearchView(store: store, onResultSelected: onResultSelected)
      )
      hostingController = host
      host.view.backgroundColor = .systemBackground
      host.view.isOpaque = true
      addChild(host)
      view.insertSubview(host.view, at: 0)
      host.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        host.view.topAnchor.constraint(equalTo: view.topAnchor),
        host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
      host.didMove(toParent: self)
    }
  }

  func updateSearchResults(for searchController: UISearchController) {
    let query = searchController.searchBar.text ?? ""
    store.setQuery(query)
    onQueryChanged(query)
  }

  func applyResults(payload: Any?) { store.apply(payload: payload) }

  func endSearchEditing() {
    searchController.searchBar.searchTextField.resignFirstResponder()
    searchController.searchBar.endEditing(true)
    view.endEditing(true)
    view.window?.endEditing(true)
  }

  func prepareForActivation() {
    endSearchEditing()
    searchController.searchBar.text = ""
    store.setQuery("")
    view.alpha = 1
    view.isHidden = false
  }

  func willPresentSearchController(_ searchController: UISearchController) {
    onSearchBegan?()
  }

  func didDismissSearchController(_ searchController: UISearchController) {
    endSearchEditing()
    searchController.searchBar.text = ""
    onQueryChanged("")
    onDismissed()
  }

  func willDismissSearchController(_ searchController: UISearchController) {
    endSearchEditing()
    onSearchDismissalBegan?()
  }
}
