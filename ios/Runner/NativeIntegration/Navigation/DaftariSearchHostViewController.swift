import UIKit

@available(iOS 26.0, *)
final class DaftariSearchHostViewController: UIViewController, UISearchResultsUpdating, UISearchControllerDelegate {
  var onSearchBegan: (() -> Void)?
  var onSearchEnded: (() -> Void)?

  private let onQueryChanged: (String) -> Void
  private let onDismissed: () -> Void
  private let searchController = UISearchController(searchResultsController: nil)

  init(onQueryChanged: @escaping (String) -> Void, onDismissed: @escaping () -> Void) {
    self.onQueryChanged = onQueryChanged
    self.onDismissed = onDismissed
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    definesPresentationContext = true
    searchController.searchResultsUpdater = self
    searchController.delegate = self
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.hidesNavigationBarDuringPresentation = false
    navigationItem.searchController = searchController
    navigationItem.hidesSearchBarWhenScrolling = false
  }

  func updateSearchResults(for searchController: UISearchController) {
    onQueryChanged(searchController.searchBar.text ?? "")
  }

  func willPresentSearchController(_ searchController: UISearchController) {
    onSearchBegan?()
  }

  func didDismissSearchController(_ searchController: UISearchController) {
    searchController.searchBar.text = ""
    onQueryChanged("")
    onSearchEnded?()
    onDismissed()
  }
}
