import UIKit

final class NativeSearchBarView: UIView, UISearchBarDelegate {
  var onQueryChanged: ((String) -> Void)?
  var onDismissed: (() -> Void)?

  private let searchBar = UISearchBar()
  private var isSearchActive = false
  private let visibleSearchFieldHeight: CGFloat = 52

  init() {
    super.init(frame: .zero)
    translatesAutoresizingMaskIntoConstraints = false
    backgroundColor = .clear
    isHidden = true
    alpha = 0

    searchBar.translatesAutoresizingMaskIntoConstraints = false
    searchBar.delegate = self
    searchBar.searchBarStyle = .minimal
    searchBar.placeholder = "Search titles and notes"
    // The separate circular X button owns dismissal in the bottom row.
    searchBar.showsCancelButton = false
    searchBar.accessibilityLabel = "Search"
    searchBar.searchTextField.accessibilityLabel = "Search titles and notes"
    addSubview(searchBar)
    NSLayoutConstraint.activate([
      searchBar.leadingAnchor.constraint(equalTo: leadingAnchor),
      searchBar.trailingAnchor.constraint(equalTo: trailingAnchor),
      searchBar.topAnchor.constraint(equalTo: topAnchor),
      searchBar.bottomAnchor.constraint(equalTo: bottomAnchor),
      searchBar.searchTextField.heightAnchor.constraint(equalToConstant: visibleSearchFieldHeight),
    ])
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func setSearchVisible(_ visible: Bool, animated: Bool) {
    isSearchActive = visible
    if !visible {
      searchBar.resignFirstResponder()
      searchBar.text = ""
    }
    updateVisibility(animated: animated)
    if visible {
      focusSearch()
    }
  }

  func finalizeVisibleState() {
    isSearchActive = true
    isHidden = false
    alpha = 1
    transform = .identity
    isUserInteractionEnabled = true
    layoutIfNeeded()
    assert(!isHidden && alpha == 1 && transform == .identity)
    assert(frame.width > 0 && frame.height > 0)
    assert(searchBar.searchTextField.frame.width > 0)
    focusSearch()
  }

  func finalizeHiddenState() {
    isSearchActive = false
    searchBar.resignFirstResponder()
    searchBar.text = ""
    isUserInteractionEnabled = false
    alpha = 0
    transform = .identity
    isHidden = true
  }

  private func focusSearch() {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.isSearchActive else { return }
      self.searchBar.becomeFirstResponder()
    }
  }

  private func updateVisibility(animated: Bool) {
    let visible = isSearchActive
    let update = {
      self.alpha = visible ? 1 : 0
      self.isHidden = !visible
    }
    if animated && !UIAccessibility.isReduceMotionEnabled {
      UIView.animate(withDuration: 0.2, animations: update)
    } else {
      update()
    }
  }

  func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
    onQueryChanged?(searchText)
  }

}
