import SwiftUI

@available(iOS 26.0, *)
struct NativeSearchView: View {
  @ObservedObject var store: NativeSearchStore
  let onResultSelected: (String, String) -> Void

  var body: some View {
    Group {
      if store.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        ContentUnavailableView(
          "Search Daftari",
          systemImage: "magnifyingglass",
          description: Text("Search debt titles and descriptions.")
        )
        .offset(y: -24)
      } else if store.results.isEmpty {
        ContentUnavailableView(
          "No Results",
          systemImage: "magnifyingglass",
          description: Text("Try another title or description.")
        )
        .offset(y: -24)
      } else {
        List {
          ForEach(["owedToMe", "owedByMe"], id: \.self) { type in
            let matches = store.results.filter { $0.type == type }
            if !matches.isEmpty {
              Section(matches[0].sectionTitle) {
                ForEach(matches) { result in
                  Button {
                    onResultSelected(result.id, result.type)
                  } label: {
                    resultRow(result)
                  }
                  .buttonStyle(.plain)
                }
              }
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .background(Color(uiColor: .systemBackground))
  }

  private func resultRow(_ result: NativeSearchResult) -> some View {
    HStack(spacing: 12) {
      Image(systemName: result.symbolName)
        .font(.body.weight(.semibold))
        .foregroundStyle(tint(for: result.tint))
        .frame(width: 42, height: 42)
        .background(tint(for: result.tint).opacity(0.12), in: Circle())

      VStack(alignment: .leading, spacing: 3) {
        Text(result.title)
          .font(.body.weight(.semibold))
          .lineLimit(1)
        if !result.previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Text(result.previewText)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        HStack(spacing: 5) {
          Image(systemName: "calendar")
          Text(result.dateText)
          if let amountText = result.amountText {
            Text("·")
            Text(amountText)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer(minLength: 8)
      Image(systemName: "chevron.right")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
    .padding(.vertical, 5)
  }

  private func tint(for name: String) -> Color {
    switch name {
    case "blue": return .blue
    case "orange": return .orange
    default: return .clear
    }
  }
}
